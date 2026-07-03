//
//  CoachTimelineStore.swift
//  Fitness Coach
//
//  Forma — SwiftData persistence for Coach Timeline v2 events.
//

import Foundation
import SwiftData

@MainActor
final class CoachTimelineStore {

    private let store: SwiftDataStore
    private let dateProvider: DateProviding

    init(store: SwiftDataStore, dateProvider: DateProviding? = nil) {
        self.store = store
        self.dateProvider = dateProvider ?? SystemDateProvider()
    }

    // MARK: Write

    @discardableResult
    func append(_ event: CoachTimelineEvent, userId: String?) throws -> CoachTimelineEventEntity {
        if let existing = try entity(id: event.id) {
            existing.applySummaryAndPayload(from: event)
            existing.statusRaw = event.status.rawValue
            existing.confidenceRaw = event.confidence?.rawValue
            try store.save()
            return existing
        }

        let entity = CoachTimelineEventEntity(model: event, userId: userId)
        try store.insert(entity)
        return entity
    }

    func updateStatus(id: UUID, status: CoachTimelineEventStatus) throws {
        guard let entity = try entity(id: id) else { return }
        entity.statusRaw = status.rawValue
        entity.updatedAt = dateProvider.now
        try store.save()
    }

    // MARK: Read

    func fetch(
        query: CoachTimelineQuery = CoachTimelineQuery(),
        userId: String? = nil
    ) throws -> [CoachTimelineEvent] {
        let entities = try fetchEntities(query: query, userId: userId)
        return entities
            .map { $0.toModel() }
            .sorted { $0.utcTimestamp < $1.utcTimestamp }
    }

    func fetchOrderedHistory(
        userId: String? = nil,
        limit: Int? = nil
    ) throws -> [CoachTimelineEvent] {
        var query = CoachTimelineQuery(includeSuperseded: false)
        query.limit = limit
        return try fetch(query: query, userId: userId)
    }

    func entity(id: UUID) throws -> CoachTimelineEventEntity? {
        var descriptor = FetchDescriptor<CoachTimelineEventEntity>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try store.fetch(descriptor).first
    }

    // MARK: Prune

    /// Removes timeline rows older than retention while preserving same-day events.
    ///
    /// - Returns: Number of deleted rows.
    @discardableResult
    func prune(
        policy: CoachTimelinePruningPolicy = .default,
        userId: String? = nil,
        calendar: Calendar = .current
    ) throws -> Int {
        let todayLocalDate = Self.localDateString(for: dateProvider.now, calendar: calendar)
        guard let cutoffDate = calendar.date(
            byAdding: .day,
            value: -policy.detailedRetentionDays,
            to: calendar.startOfDay(for: dateProvider.now)
        ) else {
            return 0
        }

        let candidates = try fetchEntities(
            query: CoachTimelineQuery(includeSuperseded: true),
            userId: userId
        ).filter { entity in
            guard !policy.shouldNeverPrune(localDate: entity.localDate, todayLocalDate: todayLocalDate) else {
                return false
            }
            return entity.utcCreatedAt < cutoffDate
        }

        var deletedCount = 0
        var summaryReplacements: [String: (count: Int, types: Set<String>)] = [:]

        for entity in candidates {
            let type = CoachTimelineEventTypeCodec.decode(entity.eventTypeRaw)
            let status = CoachTimelineEventStatusCodec.decode(entity.statusRaw)

            if policy.preserveConfirmedMutations,
               status == .confirmed,
               isMutationEvent(type) {
                continue
            }

            if policy.dropStaleFailures,
               status == .failed || status == .rejected,
               !isMutationEvent(type) {
                try store.delete(entity)
                deletedCount += 1
                continue
            }

            if policy.isCollapsible(type) {
                if policy.writeCompactSummaries {
                    var bucket = summaryReplacements[entity.localDate] ?? (0, [])
                    bucket.count += 1
                    bucket.types.insert(entity.eventTypeRaw)
                    summaryReplacements[entity.localDate] = bucket
                }
                try store.delete(entity)
                deletedCount += 1
                continue
            }

            if !isMutationEvent(type) {
                try store.delete(entity)
                deletedCount += 1
            }
        }

        if policy.writeCompactSummaries {
            for (localDate, bucket) in summaryReplacements where bucket.count > 0 {
                let summaryEvent = CoachTimelineEvent.make(
                    type: .systemRefresh,
                    source: .system,
                    sourceAttribution: .system,
                    status: .confirmed,
                    payload: .systemRefresh(
                        SystemRefreshPayload(
                            reason: "Compact summary: pruned \(bucket.count) event(s) [\(bucket.types.sorted().joined(separator: ", "))] for \(localDate)"
                        )
                    ),
                    occurredAt: dateProvider.now,
                    calendar: calendar
                )
                _ = try append(summaryEvent, userId: userId)
            }
        }

        return deletedCount
    }

    // MARK: Helpers

    private func fetchEntities(
        query: CoachTimelineQuery,
        userId: String?
    ) throws -> [CoachTimelineEventEntity] {
        let base = try store.fetch(FetchDescriptor<CoachTimelineEventEntity>())

        let filtered = base.filter { entity in
            if let userId, let entityUserId = entity.userId, entityUserId != userId {
                return false
            }
            return query.matches(entity.toModel())
        }

        if let limit = query.limit {
            let sorted = filtered.sorted { $0.utcCreatedAt > $1.utcCreatedAt }
            return Array(sorted.prefix(limit))
        }

        return filtered
    }

    private func isMutationEvent(_ type: CoachTimelineEventType) -> Bool {
        switch type {
        case .foodLogged, .foodEdited, .foodDeleted, .waterLogged, .weightLogged,
             .undoPerformed, .pendingConfirmationConfirmed:
            return true
        default:
            return false
        }
    }

    private static func localDateString(for date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
