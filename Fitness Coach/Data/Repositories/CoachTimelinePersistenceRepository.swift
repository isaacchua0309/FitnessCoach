//
//  CoachTimelinePersistenceRepository.swift
//  Fitness Coach
//
//  Forma — Low-level SwiftData access for Coach timeline events.
//
//  Internal to the application service layer. Feature code should depend on
//  `CoachTimelineStoring` instead of this type.
//

import Foundation
import SwiftData

@MainActor
final class CoachTimelinePersistenceRepository {

    private let store: SwiftDataStore
    private let dateProvider: DateProviding

    init(store: SwiftDataStore, dateProvider: DateProviding? = nil) {
        self.store = store
        self.dateProvider = dateProvider ?? SystemDateProvider()
    }

    // MARK: Write

    /// Inserts the event when no row exists for `event.id`. Duplicate ids are ignored.
    func appendIdempotent(_ event: CoachTimelineEvent, userId: String?) throws {
        let userId = try UserDataOwnerScope.requiredSessionUID(
            userId,
            operation: "append coach timeline event"
        )
        if try entity(id: event.id, userId: userId) != nil {
            return
        }
        let now = dateProvider.now
        let entity = CoachTimelineEventEntity(model: event, userId: userId)
        UserDataOwnerScope.stampNewCoachWrite(on: entity, userId: userId, now: now)
        try store.insert(entity)
    }

    func appendManyIdempotent(_ events: [CoachTimelineEvent], userId: String?) throws {
        let userId = try UserDataOwnerScope.requiredSessionUID(
            userId,
            operation: "append coach timeline events"
        )
        let existingIDs = Set(try fetchEntities(
            query: CoachTimelineQuery(includeSuperseded: true),
            userId: userId
        ).map(\.id))

        var inserted = false
        let now = dateProvider.now
        for event in events {
            guard !existingIDs.contains(event.id) else { continue }
            let entity = CoachTimelineEventEntity(model: event, userId: userId)
            UserDataOwnerScope.stampNewCoachWrite(on: entity, userId: userId, now: now)
            store.modelContext.insert(entity)
            inserted = true
        }

        if inserted {
            try store.save()
        }
    }

    func updateStatus(id: UUID, status: CoachTimelineEventStatus, userId: String?) throws {
        guard let entity = try entity(id: id, userId: userId) else { return }
        let now = dateProvider.now
        entity.statusRaw = status.rawValue
        entity.updatedAt = now
        UserDataOwnerScope.touchCoachWrite(on: entity, now: now)
        try store.save()
    }

    func insert(_ event: CoachTimelineEvent, userId: String?) throws {
        let userId = try UserDataOwnerScope.requiredSessionUID(
            userId,
            operation: "insert coach timeline event"
        )
        let now = dateProvider.now
        let entity = CoachTimelineEventEntity(model: event, userId: userId)
        UserDataOwnerScope.stampNewCoachWrite(on: entity, userId: userId, now: now)
        try store.insert(entity)
    }

    // MARK: Read

    func fetch(
        query: CoachTimelineQuery = CoachTimelineQuery(),
        userId: String? = nil
    ) throws -> [CoachTimelineEvent] {
        try fetchEntities(query: query, userId: userId)
            .map { $0.toModelSafe() }
            .sorted(by: Self.chronologicalSort)
    }

    func event(id: UUID, userId: String?) throws -> CoachTimelineEvent? {
        guard let entity = try entity(id: id, userId: userId) else { return nil }
        return entity.toModelSafe()
    }

    func entity(id: UUID, userId: String?) throws -> CoachTimelineEventEntity? {
        guard let entity = try entity(id: id) else { return nil }
        guard UserDataOwnerScope.isCoachRowVisible(entityUserId: entity.userId, sessionUID: userId) else {
            return nil
        }
        return entity
    }

    func entity(id: UUID) throws -> CoachTimelineEventEntity? {
        var descriptor = FetchDescriptor<CoachTimelineEventEntity>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try store.fetch(descriptor).first
    }

    // MARK: Compaction

    /// Applies age and per-day caps from `CoachTimelineCompactionPolicy`.
    ///
    /// - Returns: Number of deleted rows.
    @discardableResult
    func deleteEventsOlderThan(
        policy: CoachTimelineCompactionPolicy = .default,
        userId: String? = nil,
        calendar: Calendar = .current
    ) throws -> Int {
        guard userId != nil else { return 0 }

        let todayLocalDate = Self.localDateString(for: dateProvider.now, calendar: calendar)
        guard let cutoffDate = calendar.date(
            byAdding: .day,
            value: -policy.retainDays,
            to: calendar.startOfDay(for: dateProvider.now)
        ) else {
            return 0
        }

        var deletedCount = 0
        let allEntities = try fetchEntities(
            query: CoachTimelineQuery(includeSuperseded: true),
            userId: userId
        )

        for entity in allEntities {
            guard !Self.isSameDay(localDate: entity.localDate, todayLocalDate: todayLocalDate) else {
                continue
            }
            guard entity.utcCreatedAt < cutoffDate else { continue }

            let model = entity.toModelSafe()
            if policy.shouldPreserve(model) { continue }

            let status = CoachTimelineEventStatusCodec.decode(entity.statusRaw)
            let type = CoachTimelineEventTypeCodec.decode(entity.eventTypeRaw)

            if policy.dropStaleFailures,
               status == .failed || status == .rejected,
               !Self.isMutationEvent(type) {
                try store.delete(entity)
                deletedCount += 1
                continue
            }

            if policy.isCollapsible(type) || !Self.isMutationEvent(type) {
                try store.delete(entity)
                deletedCount += 1
            }
        }

        deletedCount += try enforcePerDayCap(
            policy: policy,
            userId: userId,
            todayLocalDate: todayLocalDate
        )

        return deletedCount
    }

    // MARK: Helpers

    private func fetchEntities(
        query: CoachTimelineQuery,
        userId: String?
    ) throws -> [CoachTimelineEventEntity] {
        let base = try store.fetch(FetchDescriptor<CoachTimelineEventEntity>())

        let filtered = UserDataOwnerScope.filterVisibleCoachEntities(base, sessionUID: userId)
            .filter { query.matches($0.toModelSafe()) }

        if let limit = query.limit {
            let sorted = filtered.sorted { $0.utcCreatedAt > $1.utcCreatedAt }
            return Array(sorted.prefix(limit))
        }

        return filtered
    }

    private func enforcePerDayCap(
        policy: CoachTimelineCompactionPolicy,
        userId: String?,
        todayLocalDate: String
    ) throws -> Int {
        var deletedCount = 0
        let entities = try fetchEntities(
            query: CoachTimelineQuery(includeSuperseded: true),
            userId: userId
        )

        let grouped = Dictionary(grouping: entities, by: \.localDate)
        for (localDate, dayEntities) in grouped {
            guard localDate != todayLocalDate else { continue }
            guard dayEntities.count > policy.maxEventsPerDay else { continue }

            let sorted = dayEntities.sorted { $0.utcCreatedAt > $1.utcCreatedAt }
            var remaining = sorted.count
            var deletable = sorted.filter { entity in
                let model = entity.toModelSafe()
                if policy.shouldPreserve(model) { return false }
                return policy.isCollapsible(CoachTimelineEventTypeCodec.decode(entity.eventTypeRaw))
            }

            while remaining > policy.maxEventsPerDay,
                  remaining > policy.minimumEventsPerDay,
                  let entity = deletable.popLast() {
                try store.delete(entity)
                deletedCount += 1
                remaining -= 1
            }
        }

        return deletedCount
    }

    static func chronologicalSort(_ lhs: CoachTimelineEvent, _ rhs: CoachTimelineEvent) -> Bool {
        if lhs.utcTimestamp == rhs.utcTimestamp {
            return lhs.id.uuidString < rhs.id.uuidString
        }
        return lhs.utcTimestamp < rhs.utcTimestamp
    }

    private static func isMutationEvent(_ type: CoachTimelineEventType) -> Bool {
        switch type {
        case .foodLogged, .foodEdited, .foodDeleted, .waterLogged, .weightLogged,
             .undoPerformed, .pendingConfirmationConfirmed:
            return true
        default:
            return false
        }
    }

    private static func isSameDay(localDate: String, todayLocalDate: String) -> Bool {
        localDate == todayLocalDate
    }

    private static func localDateString(for date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    #if DEBUG
    @discardableResult
    func deleteEvents(withIDs ids: Set<UUID>, userId: String? = nil) throws -> Int {
        guard !ids.isEmpty else { return 0 }

        var deletedCount = 0
        for id in ids {
            guard let entity = try entity(id: id, userId: userId) else { continue }
            try store.delete(entity)
            deletedCount += 1
        }

        if deletedCount > 0 {
            try store.save()
        }
        return deletedCount
    }
    #endif
}
