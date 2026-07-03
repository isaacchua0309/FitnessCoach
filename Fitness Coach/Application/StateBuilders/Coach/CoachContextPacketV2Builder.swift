//
//  CoachContextPacketV2Builder.swift
//  Fitness Coach
//
//  Forma — Assembles CoachContextPacketV2 from authoritative app state and timeline.
//
//  Read-only: never mutates nutrition truth. Individual source failures degrade
//  into `missingData` instead of crashing the caller.
//

import Foundation
import OSLog

@MainActor
struct CoachContextPacketV2Builder {

    static let defaultTimelineEventLimit = 20
    static let recentChatMessageLimit = 5
    static let sparseTodayEventThreshold = 4
    static let crossDayLookbackDays = 7
    static let commonFoodLookbackDays = 14

    private let dailyLogService: DailyLogService?
    private let foodLogService: FoodLogService?
    private let waterLogService: WaterLogService?
    private let weightLogService: WeightLogService?
    private let userProfileService: (any UserProfileReading)?
    private let healthActivityQuery: HealthActivityQueryService?
    private let healthIntelligenceSnapshotProvider: (any HealthIntelligenceSnapshotServing)?
    private let timelineStore: (any CoachTimelineStoring)?
    private let timelineBackfillService: (any CoachTimelineBackfilling)?
    private let timelineRecorder: (any CoachTimelineRecording)?
    private let dateProvider: DateProviding
    private let calendar: Calendar
    private let loadHealthIntelligence: () -> Bool
    private let logger = Logger(subsystem: "Forma", category: "CoachContextPacketV2")

    init(
        dailyLogService: DailyLogService? = nil,
        foodLogService: FoodLogService? = nil,
        waterLogService: WaterLogService? = nil,
        weightLogService: WeightLogService? = nil,
        userProfileService: (any UserProfileReading)? = nil,
        healthActivityQuery: HealthActivityQueryService? = nil,
        healthIntelligenceSnapshotProvider: (any HealthIntelligenceSnapshotServing)? = nil,
        timelineStore: (any CoachTimelineStoring)? = nil,
        timelineBackfillService: (any CoachTimelineBackfilling)? = nil,
        timelineRecorder: (any CoachTimelineRecording)? = nil,
        dateProvider: DateProviding? = nil,
        calendar: Calendar = .current,
        loadHealthIntelligence: @escaping () -> Bool = { HealthIntelligenceFeatureFlags.shouldCoachLoadHealthIntelligence }
    ) {
        self.dailyLogService = dailyLogService
        self.foodLogService = foodLogService
        self.waterLogService = waterLogService
        self.weightLogService = weightLogService
        self.userProfileService = userProfileService
        self.healthActivityQuery = healthActivityQuery
        self.healthIntelligenceSnapshotProvider = healthIntelligenceSnapshotProvider
        self.timelineStore = timelineStore
        self.timelineBackfillService = timelineBackfillService
        self.timelineRecorder = timelineRecorder
        self.dateProvider = dateProvider ?? SystemDateProvider()
        self.calendar = calendar
        self.loadHealthIntelligence = loadHealthIntelligence
    }

    func makeContext(
        recentMessages: [ChatMessage],
        currentUserMessage: String? = nil,
        mode: CoachContextGenerationMode = .live
    ) async -> CoachContextPacketV2 {
        let now = dateProvider.now
        let todayLocalDate = CoachContextMeta.make(generatedAt: now, calendar: calendar).localDate

        await timelineBackfillService?.runBackfill()

        var assumptions: [CoachAssumptionContext] = []
        var sources: [String] = []
        var healthAccessDenied = false

        let profile = makeProfileContext(sources: &sources)
        let dailyLog = readTodayLog(sources: &sources)

        let foodEntries = readFoodEntries(for: now, sources: &sources)
        _ = readWaterEntries(for: now, sources: &sources)
        let weightEntries = readWeightEntries(for: now, sources: &sources)

        let healthSnapshot = await loadHealthSnapshot(on: now)
        let workouts = await readWorkouts(on: now, healthAccessDenied: &healthAccessDenied, sources: &sources)
        let stepsResult = await readSteps(on: now, snapshot: healthSnapshot, healthAccessDenied: &healthAccessDenied, sources: &sources)

        let healthIntelligence = makeHealthIntelligence(from: healthSnapshot)
        if healthIntelligence != nil {
            sources.append("healthIntelligence")
        }

        let today = makeTodayPacket(
            dailyLog: dailyLog,
            foodEntries: foodEntries,
            weightEntries: weightEntries,
            steps: stepsResult,
            workouts: workouts
        )
        let training = makeTrainingContext(
            workouts: workouts,
            healthIntelligence: healthIntelligence
        )

        let timelineEvents = await loadTimelineEvents(
            now: now,
            todayLocalDate: todayLocalDate
        )
        let timelineContextEvents = CoachContextPacketV2TimelineSelector.makeContextEvents(
            from: timelineEvents,
            todayLocalDate: todayLocalDate,
            limit: Self.defaultTimelineEventLimit
        )

        var chatMessages = makeChatMessages(from: recentMessages, currentUserMessage: currentUserMessage)
        let recentMeals = foodEntries.suffix(CoachContextPacketV2Limits.maxRecentMeals).map(CoachRecentMealContext.from)
        let commonFoods = makeCommonFoods(endingOn: now)

        var missingData = makeMissingData(
            stepsResult: stepsResult,
            healthAccessDenied: healthAccessDenied,
            healthIntelligence: healthIntelligence,
            healthSnapshot: healthSnapshot,
            foodEntries: foodEntries,
            weightEntries: weightEntries,
            dailyLog: dailyLog,
            timelineEventCount: timelineContextEvents.count
        )

        assumptions.append(contentsOf: makeAssumptions(
            stepsResult: stepsResult,
            workouts: workouts,
            timelineBackfillRan: timelineBackfillService != nil
        ))

        if dailyLog != nil { sources.append("swiftData") }
        if timelineStore != nil { sources.append("coachTimeline") }
        if healthActivityQuery != nil { sources.append("healthKit") }

        var packet = CoachContextPacketV2(
            meta: CoachContextMeta.make(generatedAt: now, calendar: calendar),
            profile: profile,
            today: today,
            training: training,
            healthIntelligence: healthIntelligence,
            timeline: CoachContextTimelinePacket(recentEvents: timelineContextEvents),
            recentChatMessages: chatMessages,
            recentMealsStructured: Array(recentMeals),
            commonFoods: commonFoods,
            missingData: missingData,
            assumptions: assumptions,
            generationMode: mode,
            sourceAttribution: CoachContextSourceAttribution(
                generationMode: mode,
                timelineEventCount: timelineContextEvents.count,
                recentMealCount: recentMeals.count,
                commonFoodCount: commonFoods.count,
                healthIntelligenceIncluded: healthIntelligence != nil,
                sources: Array(Set(sources)).sorted()
            )
        )

        packet = CoachContextPacketV2SizeCompactor.compact(packet)

        recordContextGenerated(packet: packet, mode: mode, now: now)

        FormaPipelineTracer.event(
            stage: .context,
            level: .debug,
            message: "CoachContextPacketV2 assembled",
            fields: [
                "mode": mode.rawValue,
                "timelineEvents": String(packet.timeline.recentEvents.count),
                "chatMessages": String(packet.recentChatMessages.count),
                "bytes": String(packet.estimatedEncodedByteCount()),
                "missingSignals": String(packet.missingData.missingSignalLabels.count)
            ]
        )

        return packet
    }

    // MARK: Reads

    private func readTodayLog(sources: inout [String]) -> DailyLog? {
        guard let dailyLogService else { return nil }
        do {
            let log = try dailyLogService.getTodayLog()
            sources.append("dailyLog")
            return log
        } catch {
            logReadFailure("dailyLog", error: error)
            return nil
        }
    }

    private func readFoodEntries(for date: Date, sources: inout [String]) -> [FoodEntry] {
        guard let foodLogService else { return [] }
        do {
            let entries = try foodLogService.getFoodEntries(for: date)
            if !entries.isEmpty { sources.append("foodLog") }
            return entries
        } catch {
            logReadFailure("foodLog", error: error)
            return []
        }
    }

    private func readWaterEntries(for date: Date, sources: inout [String]) -> [WaterEntry] {
        guard let waterLogService else { return [] }
        do {
            let entries = try waterLogService.getWaterEntries(for: date)
            if !entries.isEmpty { sources.append("waterLog") }
            return entries
        } catch {
            logReadFailure("waterLog", error: error)
            return []
        }
    }

    private func readWeightEntries(for date: Date, sources: inout [String]) -> [WeightEntry] {
        guard let weightLogService else { return [] }
        let dayStart = calendar.startOfDay(for: date)
        do {
            let entries = try weightLogService.getWeightEntries(from: dayStart, to: dayStart)
            if !entries.isEmpty { sources.append("weightLog") }
            return entries
        } catch {
            logReadFailure("weightLog", error: error)
            return []
        }
    }

    private func loadHealthSnapshot(on date: Date) async -> HealthIntelligenceSnapshot? {
        guard loadHealthIntelligence(), let healthIntelligenceSnapshotProvider else { return nil }
        return await healthIntelligenceSnapshotProvider.loadTodaySnapshot(for: date, calendar: calendar)
    }

    private func readWorkouts(
        on date: Date,
        healthAccessDenied: inout Bool,
        sources: inout [String]
    ) async -> [HealthWorkoutRecord] {
        guard let healthActivityQuery else { return [] }
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? date
        let workouts = await healthActivityQuery.workouts(from: dayStart, to: dayEnd)
        if !workouts.isEmpty {
            sources.append("healthWorkouts")
        }
        return workouts
    }

    private struct StepsReadResult {
        var value: Int?
        var asOf: Date?
        var confidence: CoachContextConfidence
        var accessDenied: Bool
    }

    private func readSteps(
        on date: Date,
        snapshot: HealthIntelligenceSnapshot?,
        healthAccessDenied: inout Bool,
        sources: inout [String]
    ) async -> StepsReadResult {
        if let healthActivityQuery {
            do {
                let steps = try await healthActivityQuery.stepsToday(on: date, calendar: calendar)
                sources.append("healthSteps")
                return StepsReadResult(
                    value: steps,
                    asOf: dateProvider.now,
                    confidence: .medium,
                    accessDenied: false
                )
            } catch {
                if HealthKitOptionalAccessPolicy.isOptionalAccessFailure(error) {
                    healthAccessDenied = true
                    return StepsReadResult(value: nil, asOf: nil, confidence: .unknown, accessDenied: true)
                }
                logReadFailure("steps", error: error)
            }
        }

        if let steps = snapshot?.activity.steps {
            sources.append("healthIntelligenceSteps")
            return StepsReadResult(
                value: steps,
                asOf: dateProvider.now,
                confidence: .low,
                accessDenied: false
            )
        }

        return StepsReadResult(value: nil, asOf: nil, confidence: .unknown, accessDenied: healthAccessDenied)
    }

    private func loadTimelineEvents(now: Date, todayLocalDate: String) async -> [CoachTimelineEvent] {
        guard let timelineStore else { return [] }

        do {
            var todayEvents = try await timelineStore.events(forLocalDate: todayLocalDate)
            let todayCount = todayEvents.count

            if todayCount < Self.sparseTodayEventThreshold {
                let lookbackStart = calendar.date(
                    byAdding: .day,
                    value: -Self.crossDayLookbackDays,
                    to: calendar.startOfDay(for: now)
                ) ?? now
                let rangeEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
                let ranged = try await timelineStore.events(from: lookbackStart, to: rangeEnd)

                var merged: [UUID: CoachTimelineEvent] = [:]
                for event in ranged + todayEvents {
                    merged[event.id] = event
                }
                todayEvents = merged.values.sorted { $0.utcTimestamp < $1.utcTimestamp }
            }

            return todayEvents.filter { $0.status != .superseded && $0.type != .contextGenerated }
        } catch {
            logReadFailure("timeline", error: error)
            return []
        }
    }

    // MARK: Builders

    private func makeProfileContext(sources: inout [String]) -> CoachUserProfileContext? {
        guard let profile = try? userProfileService?.getCurrentProfile() else { return nil }
        sources.append("profile")
        return CoachUserProfileContext(
            age: profile.age,
            sex: profile.sex,
            heightCm: profile.heightCm,
            currentWeightKg: profile.currentWeightKg,
            goalWeightKg: profile.goalWeightKg,
            activityLevel: profile.activityLevel,
            trainingFrequencyPerWeek: profile.trainingFrequencyPerWeek,
            goalType: Self.goalType(for: profile)
        )
    }

    private func makeHealthIntelligence(
        from snapshot: HealthIntelligenceSnapshot?
    ) -> CoachHealthIntelligenceContext? {
        guard loadHealthIntelligence(), let snapshot else { return nil }
        let built = CoachHealthIntelligenceContextBuilder.build(from: snapshot, calendar: calendar)
        let awareness = CoachAIActivityContextResolver.healthIntelligenceAwarenessAvailable(
            snapshot: snapshot,
            healthIntelligence: built
        )
        return awareness ? built : nil
    }

    private func makeTodayPacket(
        dailyLog: DailyLog?,
        foodEntries: [FoodEntry],
        weightEntries: [WeightEntry],
        steps: StepsReadResult,
        workouts: [HealthWorkoutRecord]
    ) -> CoachContextTodayPacket? {
        guard let dailyLog else { return nil }

        let nutrition = DailyNutritionSummaryBuilder.build(from: dailyLog)
        let weightKg = weightEntries.last?.weightKg ?? dailyLog.weightKg
        let workoutCalories = workouts.compactMap(\.activeCalories).reduce(0, +)

        return CoachContextTodayPacket(
            targets: CoachTodayTargetsContext(
                calorieTarget: nutrition.targets.calories,
                proteinTarget: nutrition.targets.protein,
                carbsTarget: nutrition.targets.carbs,
                fatTarget: nutrition.targets.fat,
                waterTargetMl: nutrition.water.targetMl
            ),
            nutrition: CoachTodayNutritionContext(
                caloriesConsumed: nutrition.totals.calories,
                caloriesRemaining: nutrition.remaining.calories,
                proteinConsumed: nutrition.totals.protein,
                proteinRemaining: nutrition.remaining.protein,
                carbsConsumed: nutrition.totals.carbs,
                carbsRemaining: nutrition.remaining.carbs,
                fatConsumed: nutrition.totals.fat,
                fatRemaining: nutrition.remaining.fat
            ),
            hydration: CoachTodayHydrationContext(
                waterConsumedMl: nutrition.water.consumedMl,
                waterRemainingMl: nutrition.water.remainingMl
            ),
            weight: weightKg.map { CoachTodayWeightContext(weightKg: $0) },
            steps: steps.value.map {
                CoachContextSourcedInt(
                    value: $0,
                    source: "healthKit",
                    asOf: steps.asOf,
                    confidence: steps.confidence
                )
            },
            workoutCaloriesBurned: workoutCalories > 0
                ? CoachContextSourcedInt(
                    value: workoutCalories,
                    source: "healthKit",
                    asOf: dateProvider.now,
                    confidence: .medium
                )
                : nil
        )
    }

    private func makeTrainingContext(
        workouts: [HealthWorkoutRecord],
        healthIntelligence: CoachHealthIntelligenceContext?
    ) -> CoachTrainingContext? {
        guard !workouts.isEmpty || healthIntelligence != nil else { return nil }

        return CoachTrainingContext(
            workoutsToday: workouts.isEmpty ? healthIntelligence?.workoutCompletedToday == true ? 1 : 0 : workouts.count,
            workouts: workouts.map(CoachContextWorkoutSummary.from),
            trainingLoad: healthIntelligence?.trainingLoadStatus,
            recoveryStatus: healthIntelligence?.recoveryStatus,
            readiness: healthIntelligence?.recoveryConfidence
        )
    }

    private func makeChatMessages(
        from messages: [ChatMessage],
        currentUserMessage: String?
    ) -> [CoachChatMessageContext] {
        var combined = messages
        if let currentUserMessage {
            let trimmed = currentUserMessage.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                combined.append(
                    ChatMessage(
                        role: .user,
                        text: trimmed,
                        createdAt: dateProvider.now
                    )
                )
            }
        }

        return combined
            .suffix(Self.recentChatMessageLimit)
            .map { CoachChatMessageContext.from(message: $0) }
    }

    private func makeCommonFoods(endingOn date: Date) -> [CoachCommonFoodContext] {
        guard let foodLogService else { return [] }

        struct Aggregate {
            var count: Int
            var lastLoggedAt: Date
            var calories: [Int]
        }

        var aggregates: [String: Aggregate] = [:]
        let todayStart = calendar.startOfDay(for: date)

        for offset in 0..<Self.commonFoodLookbackDays {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: todayStart) else { continue }
            let entries = (try? foodLogService.getFoodEntries(for: day)) ?? []
            for entry in entries {
                let key = entry.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                guard !key.isEmpty else { continue }
                var aggregate = aggregates[key] ?? Aggregate(count: 0, lastLoggedAt: entry.createdAt, calories: [])
                aggregate.count += 1
                if entry.createdAt > aggregate.lastLoggedAt {
                    aggregate.lastLoggedAt = entry.createdAt
                }
                aggregate.calories.append(entry.calories)
                aggregates[key] = aggregate
            }
        }

        return aggregates
            .map { name, aggregate in
                let typicalCalories: Int? = {
                    guard !aggregate.calories.isEmpty else { return nil }
                    return aggregate.calories.reduce(0, +) / aggregate.calories.count
                }()
                return CoachCommonFoodContext(
                    name: name,
                    logCount: aggregate.count,
                    lastLoggedAt: aggregate.lastLoggedAt,
                    typicalCalories: typicalCalories
                )
            }
            .sorted {
                if $0.logCount == $1.logCount {
                    return ($0.lastLoggedAt ?? .distantPast) > ($1.lastLoggedAt ?? .distantPast)
                }
                return ($0.logCount ?? 0) > ($1.logCount ?? 0)
            }
            .prefix(CoachContextPacketV2Limits.maxCommonFoods)
            .map { $0 }
    }

    private func makeMissingData(
        stepsResult: StepsReadResult,
        healthAccessDenied: Bool,
        healthIntelligence: CoachHealthIntelligenceContext?,
        healthSnapshot: HealthIntelligenceSnapshot?,
        foodEntries: [FoodEntry],
        weightEntries: [WeightEntry],
        dailyLog: DailyLog?,
        timelineEventCount: Int
    ) -> CoachMissingDataContext {
        let missingSignals = Set(healthIntelligence?.missingSignals.map { $0.lowercased() } ?? [])
        let recoverySignals = healthSnapshot?.recovery.missingSignals ?? []

        return CoachMissingDataContext(
            stepsMissing: stepsResult.value == nil,
            workoutPermissionDeniedOrUnavailable: healthAccessDenied || (healthActivityQuery == nil),
            sleepMissing: missingSignals.contains(where: { $0.contains("sleep") })
                || recoverySignals.contains(.sleep),
            hrvMissing: missingSignals.contains(where: { $0.contains("hrv") })
                || recoverySignals.contains(.hrv),
            weightMissing: weightEntries.isEmpty && dailyLog?.weightKg == nil,
            noRecentMeals: foodEntries.isEmpty,
            noTimelineHistory: timelineEventCount == 0
        )
    }

    private func makeAssumptions(
        stepsResult: StepsReadResult,
        workouts: [HealthWorkoutRecord],
        timelineBackfillRan: Bool
    ) -> [CoachAssumptionContext] {
        var assumptions: [CoachAssumptionContext] = []

        assumptions.append(
            CoachAssumptionContext(
                key: "workout_calories_source",
                detail: "Workout calories are summed from Apple Health workout samples; legacy daily-log workout calories are excluded.",
                confidence: workouts.isEmpty ? .unknown : .medium
            )
        )

        if stepsResult.value != nil {
            assumptions.append(
                CoachAssumptionContext(
                    key: "steps_source",
                    detail: "Steps are read from Apple Health when authorized.",
                    confidence: stepsResult.confidence
                )
            )
        }

        if timelineBackfillRan {
            assumptions.append(
                CoachAssumptionContext(
                    key: "timeline_backfill",
                    detail: "Timeline may include idempotent backfill events from persisted logs before live recorder events exist.",
                    confidence: .high
                )
            )
        }

        return assumptions
    }

    private func recordContextGenerated(
        packet: CoachContextPacketV2,
        mode: CoachContextGenerationMode,
        now: Date
    ) {
        timelineRecorder?.recordContextGenerated(
            payload: ContextGenerationPayload(
                lookbackDays: Self.crossDayLookbackDays,
                timelineEventCount: packet.timeline.recentEvents.count,
                recentMessageCount: packet.recentChatMessages.count,
                hasTodaySummary: packet.today != nil,
                hasHealthIntelligence: packet.healthIntelligence != nil,
                healthIntelligenceAwarenessAvailable: packet.healthIntelligence != nil,
                contextByteEstimate: packet.estimatedEncodedByteCount(),
                trigger: mode.rawValue
            ),
            occurredAt: now
        )
    }

    private func logReadFailure(_ source: String, error: Error) {
        logger.debug("CoachContextPacketV2 \(source, privacy: .public) read failed: \(error.localizedDescription, privacy: .public)")
    }

    private static func goalType(for profile: UserProfile) -> String? {
        if let weeklyLoss = profile.targets.expectedWeeklyWeightLossKg {
            if weeklyLoss > 0.05 { return "Lose Fat" }
            if weeklyLoss < -0.05 { return "Gain Muscle" }
            return "Maintain"
        }
        switch profile.targets.aggressiveness {
        case .conservative, .moderate:
            return "Maintain"
        case .aggressive:
            return "Lose Fat"
        }
    }
}

// MARK: - Timeline selection

enum CoachContextPacketV2TimelineSelector {

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
        .weightLogged
    ]

    static func selectEvents(
        from events: [CoachTimelineEvent],
        todayLocalDate: String,
        limit: Int
    ) -> [CoachTimelineEvent] {
        let sorted = events
            .filter { $0.status != .superseded && $0.type != .contextGenerated }
            .sorted { $0.utcTimestamp > $1.utcTimestamp }

        var selected: [UUID: CoachTimelineEvent] = [:]

        func include(_ event: CoachTimelineEvent) {
            selected[event.id] = event
        }

        for event in sorted where event.localDate == todayLocalDate {
            if todayMutationTypes.contains(event.type), event.status == .confirmed {
                include(event)
            }
        }

        for event in sorted where event.localDate == todayLocalDate {
            if event.type == .pendingConfirmationCreated, event.status == .pending {
                include(event)
            }
        }

        for event in sorted where event.localDate == todayLocalDate && photoEventTypes.contains(event.type) {
            include(event)
        }

        if let workout = sorted.first(where: { $0.type == .workoutDetected }) {
            include(workout)
        }
        if let steps = sorted.first(where: { $0.type == .stepsUpdated }) {
            include(steps)
        }

        let todayCount = sorted.filter { $0.localDate == todayLocalDate }.count
        if todayCount < CoachContextPacketV2Builder.sparseTodayEventThreshold {
            for event in sorted where event.localDate != todayLocalDate {
                include(event)
                if selected.count >= limit { break }
            }
        }

        for event in sorted {
            include(event)
            if selected.count >= limit { break }
        }

        return selected.values.sorted { $0.utcTimestamp < $1.utcTimestamp }
    }

    static func makeContextEvents(
        from events: [CoachTimelineEvent],
        todayLocalDate: String,
        limit: Int
    ) -> [CoachTimelineContextEvent] {
        selectEvents(from: events, todayLocalDate: todayLocalDate, limit: limit).map { event in
            CoachTimelineContextEvent.from(
                event: event,
                summary: CoachTimelineEventSummaryBuilder.summary(for: event)
            )
        }
    }
}

// MARK: - Size compaction

enum CoachContextPacketV2SizeCompactor {

    static func compact(
        _ packet: CoachContextPacketV2,
        byteLimit: Int = CoachContextPacketV2Limits.defaultMaxEncodedBytes
    ) -> CoachContextPacketV2 {
        var result = packet.clampedForTransport()
        var bytes = result.estimatedEncodedByteCount()
        guard bytes > byteLimit else { return result }

        result.recentChatMessages = result.recentChatMessages.map { message in
            guard message.role == ChatMessageRole.assistant.rawValue else { return message }
            var compact = message
            compact.textPreview = truncate(message.textPreview, maxLength: 80)
            return compact
        }
        bytes = result.estimatedEncodedByteCount()
        guard bytes > byteLimit else { return result }

        let protectedIDs = protectedTimelineEventIDs(in: result)
        var events = result.timeline.recentEvents
        while bytes > byteLimit {
            guard let removalIndex = events.firstIndex(where: { event in
                !protectedIDs.contains(event.id) && isLowValueSystemEvent(event)
            }) else {
                break
            }
            events.remove(at: removalIndex)
            result.timeline.recentEvents = events
            bytes = result.estimatedEncodedByteCount()
        }

        if bytes > byteLimit {
            events = events.map { event in
                guard event.type == CoachTimelineEventType.assistantMessage.rawValue else { return event }
                var compact = event
                compact.summary = truncate(event.summary, maxLength: 60)
                compact.compactPayload = nil
                return compact
            }
            result.timeline.recentEvents = events
        }

        return result.clampedForTransport()
    }

    private static func protectedTimelineEventIDs(in packet: CoachContextPacketV2) -> Set<UUID> {
        let today = packet.meta.localDate
        let protectedTypes: Set<String> = [
            CoachTimelineEventType.foodLogged.rawValue,
            CoachTimelineEventType.waterLogged.rawValue,
            CoachTimelineEventType.weightLogged.rawValue,
            CoachTimelineEventType.pendingConfirmationCreated.rawValue,
            CoachTimelineEventType.photoAttached.rawValue,
            CoachTimelineEventType.photoAnalysisStarted.rawValue,
            CoachTimelineEventType.photoAnalysisCompleted.rawValue,
            CoachTimelineEventType.photoAnalysisFailed.rawValue,
            CoachTimelineEventType.workoutDetected.rawValue,
            CoachTimelineEventType.stepsUpdated.rawValue
        ]

        return Set(
            packet.timeline.recentEvents.compactMap { event in
                guard protectedTypes.contains(event.type) else { return nil }
                if [
                    CoachTimelineEventType.foodLogged.rawValue,
                    CoachTimelineEventType.waterLogged.rawValue,
                    CoachTimelineEventType.weightLogged.rawValue
                ].contains(event.type) {
                    return event.timestampLocalDateOrMeta(today) == today ? event.id : nil
                }
                return event.id
            }
        )
    }

    private static func isLowValueSystemEvent(_ event: CoachTimelineContextEvent) -> Bool {
        switch event.type {
        case CoachTimelineEventType.systemRefresh.rawValue,
             CoachTimelineEventType.contextGenerated.rawValue,
             CoachTimelineEventType.healthDataUnavailable.rawValue,
             CoachTimelineEventType.stepsUpdated.rawValue:
            return true
        default:
            return event.source == CoachTimelineEventSourceAttribution.system.rawValue
                && event.type != CoachTimelineEventType.foodLogged.rawValue
        }
    }

    private static func truncate(_ value: String, maxLength: Int) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > maxLength else { return trimmed }
        let index = trimmed.index(trimmed.startIndex, offsetBy: maxLength)
        return String(trimmed[..<index]) + "…"
    }
}

private extension CoachTimelineContextEvent {

    func timestampLocalDateOrMeta(_ fallbackToday: String) -> String {
        let timestamps = CoachTimelineEvent.makeTimestamps(from: timestamp)
        return timestamps.localDate.isEmpty ? fallbackToday : timestamps.localDate
    }
}