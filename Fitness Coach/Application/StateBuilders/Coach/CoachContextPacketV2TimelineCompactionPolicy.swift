//
//  CoachContextPacketV2TimelineCompactionPolicy.swift
//  Fitness Coach
//
//  Deterministic priority-based timeline compaction for CoachContextPacketV2.
//

import Foundation

enum CoachContextTimelineEventPriority: Int, Comparable, Sendable {
    /// Repeated low-value system events (drop first when over limit).
    case repeatedLowValue = 1
    /// Assistant messages, older steps, backend noise.
    case assistantAndSystem = 2
    /// Photo pipeline and clarifications.
    case photoAndClarification = 3
    /// Accuracy-critical facts — never drop unless impossible.
    case critical = 4

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

enum CoachContextPacketV2TimelineCompactionPolicy {

    static let dailyFoodSummaryType = "dailyFoodSummary"
    static let maxIndividualFoodEvents = 8
    static let retainedRecentFoodEvents = 6

    private static let photoEventTypes: Set<CoachTimelineEventType> = [
        .photoAttached,
        .photoAnalysisStarted,
        .photoAnalysisCompleted,
        .photoAnalysisFailed,
        .clarificationAsked,
        .clarificationAnswered
    ]

    private static let todayMutationTypes: Set<CoachTimelineEventType> = [
        .foodLogged,
        .waterLogged,
        .weightLogged,
        .foodEdited,
        .foodDeleted
    ]

    private static let excludedContextTypes: Set<CoachTimelineEventType> = [
        .unknown,
        .foodEstimateCreated,
        .foodRejected,
        .pendingConfirmationRejected,
        .pendingConfirmationConfirmed,
        .backendError,
        .authError,
        .systemRefresh,
        .contextGenerated,
        .healthDataUnavailable
    ]

    /// Whether an event may appear in AI context timeline.
    static func isContextEligible(_ event: CoachTimelineEvent) -> Bool {
        if event.status == .superseded || event.status == .rejected || event.status == .failed {
            return false
        }
        if excludedContextTypes.contains(event.type) {
            return false
        }
        if event.status == .pending, event.type != .pendingConfirmationCreated {
            return false
        }
        return true
    }

    static func compact(
        events: [CoachTimelineEvent],
        todayLocalDate: String,
        limit: Int
    ) -> (
        domainEvents: [CoachTimelineEvent],
        events: [CoachTimelineContextEvent],
        metadata: CoachContextCompactionMetadata
    ) {
        let originalCount = events.count
        let eligible = events
            .filter(isContextEligible)
            .sorted(by: stableTimestampSort)

        guard !eligible.isEmpty else {
            return (
                [],
                [],
                CoachContextCompactionMetadata(
                    originalEventCount: originalCount,
                    exportedEventCount: 0,
                    compactionReason: originalCount > 0 ? "no_eligible_timeline_events" : nil
                )
            )
        }

        let latestWorkoutID = eligible.last(where: { $0.type == .workoutDetected })?.id
        let latestStepsID = eligible.last(where: { $0.type == .stepsUpdated })?.id
        let linkedPhotoSessionIDs = photoSessionIDs(from: eligible)

        var selected = eligible
        var reasons: [String] = []

        selected = summarizeOlderFoodEventsIfNeeded(
            selected,
            todayLocalDate: todayLocalDate,
            reasons: &reasons
        )

        if selected.count > limit {
            selected = dropEventsToLimit(
                selected,
                todayLocalDate: todayLocalDate,
                limit: limit,
                latestWorkoutID: latestWorkoutID,
                latestStepsID: latestStepsID,
                linkedPhotoSessionIDs: linkedPhotoSessionIDs,
                reasons: &reasons
            )
        }

        let contextEvents = selected.map { CoachTimelineContextEvent.fromCompactedTimelineEvent($0) }

        var metadata = CoachContextCompactionMetadata()
        metadata.recordTimelineCompaction(
            originalCount: originalCount,
            exportedCount: contextEvents.count,
            reason: reasons.isEmpty ? nil : reasons.joined(separator: "; ")
        )
        return (selected, contextEvents, metadata)
    }

    static func priority(
        for event: CoachTimelineEvent,
        todayLocalDate: String,
        latestWorkoutID: UUID?,
        latestStepsID: UUID?,
        linkedPhotoSessionIDs: Set<UUID>
    ) -> CoachContextTimelineEventPriority {
        if isCritical(
            event,
            todayLocalDate: todayLocalDate,
            latestWorkoutID: latestWorkoutID,
            latestStepsID: latestStepsID
        ) {
            return .critical
        }

        if photoEventTypes.contains(event.type)
            || (event.linkedPhotoSessionId.map { linkedPhotoSessionIDs.contains($0) } ?? false)
            || event.type == .clarificationAsked
            || event.type == .clarificationAnswered {
            return .photoAndClarification
        }

        switch event.type {
        case .assistantMessage, .undoPerformed, .stepsUpdated:
            return .assistantAndSystem
        case .userMessage:
            return .photoAndClarification
        default:
            return .repeatedLowValue
        }
    }

    static func isCritical(
        _ event: CoachTimelineEvent,
        todayLocalDate: String,
        latestWorkoutID: UUID?,
        latestStepsID: UUID?
    ) -> Bool {
        if isDailyFoodSummaryEvent(event, todayLocalDate: todayLocalDate) {
            return true
        }
        if event.localDate == todayLocalDate,
           todayMutationTypes.contains(event.type),
           event.status == .confirmed {
            return true
        }
        if event.localDate == todayLocalDate,
           event.type == .pendingConfirmationCreated,
           event.status == .pending {
            return true
        }
        if event.id == latestWorkoutID || event.id == latestStepsID {
            return true
        }
        return false
    }

    // MARK: - Private

    private static func stableTimestampSort(_ lhs: CoachTimelineEvent, _ rhs: CoachTimelineEvent) -> Bool {
        if lhs.utcTimestamp != rhs.utcTimestamp {
            return lhs.utcTimestamp < rhs.utcTimestamp
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private static func dropEventsToLimit(
        _ events: [CoachTimelineEvent],
        todayLocalDate: String,
        limit: Int,
        latestWorkoutID: UUID?,
        latestStepsID: UUID?,
        linkedPhotoSessionIDs: Set<UUID>,
        reasons: inout [String]
    ) -> [CoachTimelineEvent] {
        var remaining = events
        var dropped = 0

        func removalCandidates() -> [(index: Int, event: CoachTimelineEvent, priority: CoachContextTimelineEventPriority)] {
            remaining.enumerated().map { index, event in
                (
                    index,
                    event,
                    priority(
                        for: event,
                        todayLocalDate: todayLocalDate,
                        latestWorkoutID: latestWorkoutID,
                        latestStepsID: latestStepsID,
                        linkedPhotoSessionIDs: linkedPhotoSessionIDs
                    )
                )
            }
            .filter { $0.priority != .critical }
            .sorted { lhs, rhs in
                if lhs.priority != rhs.priority {
                    return lhs.priority < rhs.priority
                }
                if lhs.event.utcTimestamp != rhs.event.utcTimestamp {
                    return lhs.event.utcTimestamp < rhs.event.utcTimestamp
                }
                return lhs.event.id.uuidString < rhs.event.id.uuidString
            }
        }

        while remaining.count > limit, let candidate = removalCandidates().first {
            remaining.remove(at: candidate.index)
            dropped += 1
        }

        if dropped > 0 {
            reasons.append("dropped_\(dropped)_lower_priority_events")
        }

        if remaining.count > limit {
            reasons.append("timeline_still_over_limit_after_priority_drop")
            remaining = Array(remaining.suffix(limit))
        }

        return remaining.sorted(by: stableTimestampSort)
    }

    private static func summarizeOlderFoodEventsIfNeeded(
        _ events: [CoachTimelineEvent],
        todayLocalDate: String,
        reasons: inout [String]
    ) -> [CoachTimelineEvent] {
        let todayFood = events.filter {
            $0.localDate == todayLocalDate
                && $0.type == .foodLogged
                && $0.status == .confirmed
        }
        guard todayFood.count > maxIndividualFoodEvents else {
            return events
        }

        let retainedIDs = Set(todayFood.suffix(retainedRecentFoodEvents).map(\.id))
        let summarized = todayFood.filter { !retainedIDs.contains($0.id) }
        guard !summarized.isEmpty else { return events }

        let totalCalories = summarized.compactMap { event -> Int? in
            guard case .foodLogged(let payload) = event.payload else { return nil }
            return payload.calories
        }.reduce(0, +)

        let summaryEvent = makeDailyFoodSummaryEvent(
            summarized: summarized,
            todayLocalDate: todayLocalDate,
            totalCalories: totalCalories
        )

        var result = events.filter { event in
            !summarized.contains(where: { $0.id == event.id })
        }
        result.append(summaryEvent)
        reasons.append("summarized_\(summarized.count)_older_food_logs")
        return result.sorted(by: stableTimestampSort)
    }

    private static func makeDailyFoodSummaryEvent(
        summarized: [CoachTimelineEvent],
        todayLocalDate: String,
        totalCalories: Int
    ) -> CoachTimelineEvent {
        let timestamps = CoachTimelineEvent.makeTimestamps(from: summarized.first?.utcTimestamp ?? Date())
        let linkedEntryIDs = summarized.compactMap(\.linkedEntryId)
        return CoachTimelineEvent(
            id: deterministicSummaryID(
                localDate: todayLocalDate,
                mealCount: summarized.count,
                totalCalories: totalCalories
            ),
            type: .assistantMessage,
            source: .system,
            sourceAttribution: .system,
            status: .confirmed,
            payload: .message(
                MessagePayload(
                    textPreview: "Earlier food logs today: \(summarized.count) meals, \(totalCalories) kcal total.",
                    role: "system"
                )
            ),
            utcTimestamp: timestamps.utc,
            localTimestamp: timestamps.localISO8601,
            timezoneIdentifier: timestamps.timezoneIdentifier,
            localDate: todayLocalDate,
            link: CoachTimelineEventLink(
                linkedEntryId: linkedEntryIDs.first,
                relatedEventIds: summarized.map(\.id)
            )
        )
    }

    static func dailyFoodSummaryContextEvent(
        from event: CoachTimelineEvent,
        mealCount: Int,
        totalCalories: Int
    ) -> CoachTimelineContextEvent {
        CoachTimelineContextEvent(
            id: event.id,
            timestamp: event.utcTimestamp,
            type: dailyFoodSummaryType,
            source: event.sourceAttribution.rawValue,
            status: event.status.rawValue,
            summary: "Earlier food logs today: \(mealCount) meals, \(totalCalories) kcal total.",
            compactPayload: [
                "mealCount": String(mealCount),
                "totalKcal": String(totalCalories)
            ],
            confidence: nil,
            linkedEntryId: event.linkedEntryId,
            linkedMessageId: event.linkedMessageId
        )
    }

    static func deterministicSummaryID(
        localDate: String,
        mealCount: Int,
        totalCalories: Int
    ) -> UUID {
        let seed = "dailyFoodSummary|\(localDate)|\(mealCount)|\(totalCalories)"
        var bytes = [UInt8](repeating: 0, count: 16)
        for (index, byte) in seed.utf8.enumerated() {
            bytes[index % 16] = bytes[index % 16] &+ byte
        }
        bytes[6] = (bytes[6] & 0x0F) | 0x40
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        let uuid: uuid_t = (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        )
        return UUID(uuid: uuid)
    }

    private static func photoSessionIDs(from events: [CoachTimelineEvent]) -> Set<UUID> {
        Set(events.compactMap(\.linkedPhotoSessionId))
    }

    private static func isDailyFoodSummaryEvent(
        _ event: CoachTimelineEvent,
        todayLocalDate: String
    ) -> Bool {
        guard event.localDate == todayLocalDate else { return false }
        guard event.link.relatedEventIds.count > 1 else { return false }
        guard case .message(let payload) = event.payload else { return false }
        return payload.textPreview.hasPrefix("Earlier food logs today:")
    }
}

private extension CoachTimelineEvent {
    var linkedPhotoSessionId: UUID? {
        link.linkedPhotoSessionId
    }
}

extension CoachTimelineContextEvent {

    static func fromCompactedTimelineEvent(_ event: CoachTimelineEvent) -> CoachTimelineContextEvent {
        if event.link.relatedEventIds.count > 1,
           case .message(let payload) = event.payload,
           payload.textPreview.hasPrefix("Earlier food logs today:") {
            let mealCount = event.link.relatedEventIds.count
            let totalCalories = Int(
                payload.textPreview
                    .split(separator: ",")
                    .last?
                    .components(separatedBy: CharacterSet.decimalDigits.inverted)
                    .joined() ?? ""
            ) ?? 0
            return CoachContextPacketV2TimelineCompactionPolicy.dailyFoodSummaryContextEvent(
                from: event,
                mealCount: mealCount,
                totalCalories: totalCalories
            )
        }
        return CoachTimelineContextEvent.from(
            event: event,
            summary: CoachTimelineEventSummaryBuilder.summary(for: event)
        )
    }
}
