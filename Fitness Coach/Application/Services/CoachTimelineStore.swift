//
//  CoachTimelineStore.swift
//  Fitness Coach
//
//  Forma — Application service for Coach timeline read/write.
//
//  Feature and AI layers depend on `CoachTimelineStoring` only. SwiftData types
//  never leak past `SwiftDataCoachTimelineStore`.
//

import Foundation

// MARK: - Protocol

/// Public Coach timeline API for append, query, status, supersede, and compaction.
protocol CoachTimelineStoring {
    func append(_ event: CoachTimelineEvent) async throws
    func appendMany(_ events: [CoachTimelineEvent]) async throws
    func events(forLocalDate localDate: String) async throws -> [CoachTimelineEvent]
    func events(from start: Date, to end: Date) async throws -> [CoachTimelineEvent]
    func recentEvents(limit: Int, before date: Date?) async throws -> [CoachTimelineEvent]
    func event(id: UUID) async throws -> CoachTimelineEvent?
    func markEventStatus(id: UUID, status: CoachTimelineEventStatus) async throws
    func supersedeEvent(id: UUID, by newEvent: CoachTimelineEvent) async throws
    func deleteEventsOlderThan(policy: CoachTimelineCompactionPolicy) async throws
}

// MARK: - Errors

enum CoachTimelineStoreError: Error, Equatable {
    case eventNotFound(UUID)
    case invalidDateRange
}

// MARK: - Implementation

/// SwiftData-backed timeline store. All persistence work is isolated on the main actor.
@MainActor
final class SwiftDataCoachTimelineStore: CoachTimelineStoring {

    /// Upper bound for per-day and ranged timeline reads used by context assembly.
    static let maxQueryEventLimit = 250

    private let repository: CoachTimelinePersistenceRepository
    private let userIdProvider: () -> String?
    private let calendar: Calendar

    init(
        repository: CoachTimelinePersistenceRepository,
        userIdProvider: @escaping () -> String? = { nil },
        calendar: Calendar = .current
    ) {
        self.repository = repository
        self.userIdProvider = userIdProvider
        self.calendar = calendar
    }

    convenience init(
        store: SwiftDataStore,
        dateProvider: DateProviding? = nil,
        userIdProvider: @escaping () -> String? = { nil },
        calendar: Calendar = .current
    ) {
        self.init(
            repository: CoachTimelinePersistenceRepository(store: store, dateProvider: dateProvider),
            userIdProvider: userIdProvider,
            calendar: calendar
        )
    }

    func append(_ event: CoachTimelineEvent) async throws {
        let userId = try UserDataOwnerScope.requiredSessionUID(
            userIdProvider(),
            operation: "append coach timeline event"
        )
        try repository.appendIdempotent(event, userId: userId)
    }

    func appendMany(_ events: [CoachTimelineEvent]) async throws {
        let userId = try UserDataOwnerScope.requiredSessionUID(
            userIdProvider(),
            operation: "append coach timeline events"
        )
        try repository.appendManyIdempotent(events, userId: userId)
    }

    func events(forLocalDate localDate: String) async throws -> [CoachTimelineEvent] {
        let query = CoachTimelineQuery(
            fromLocalDate: localDate,
            toLocalDate: localDate,
            limit: Self.maxQueryEventLimit,
            includeSuperseded: false
        )
        return try repository.fetch(query: query, userId: userIdProvider())
    }

    func events(from start: Date, to end: Date) async throws -> [CoachTimelineEvent] {
        guard start <= end else {
            throw CoachTimelineStoreError.invalidDateRange
        }

        let startLocalDate = Self.localDateString(for: start, calendar: calendar)
        let endLocalDate = Self.localDateString(for: end, calendar: calendar)
        let ranged = try repository.fetch(
            query: CoachTimelineQuery(
                fromLocalDate: startLocalDate,
                toLocalDate: endLocalDate,
                limit: Self.maxQueryEventLimit,
                includeSuperseded: false
            ),
            userId: userIdProvider()
        )
        return ranged.filter { event in
            event.utcTimestamp >= start && event.utcTimestamp <= end
        }
    }

    func recentEvents(limit: Int, before date: Date?) async throws -> [CoachTimelineEvent] {
        guard limit > 0 else { return [] }

        let fetchLimit = min(max(limit * 4, limit), Self.maxQueryEventLimit)
        let candidates = try repository.fetch(
            query: CoachTimelineQuery(
                limit: fetchLimit,
                includeSuperseded: false
            ),
            userId: userIdProvider()
        )

        let filtered = candidates.filter { event in
            guard let date else { return true }
            return event.utcTimestamp < date
        }

        let recent = filtered
            .sorted { $0.utcTimestamp > $1.utcTimestamp }
            .prefix(limit)

        return recent.sorted(by: CoachTimelinePersistenceRepository.chronologicalSort)
    }

    func event(id: UUID) async throws -> CoachTimelineEvent? {
        try repository.event(id: id, userId: userIdProvider())
    }

    func markEventStatus(id: UUID, status: CoachTimelineEventStatus) async throws {
        let userId = userIdProvider()
        guard try repository.entity(id: id, userId: userId) != nil else {
            throw CoachTimelineStoreError.eventNotFound(id)
        }
        try repository.updateStatus(id: id, status: status)
    }

    func supersedeEvent(id: UUID, by newEvent: CoachTimelineEvent) async throws {
        let userId = try UserDataOwnerScope.requiredSessionUID(
            userIdProvider(),
            operation: "supersede coach timeline event"
        )
        guard try repository.entity(id: id, userId: userId) != nil else {
            throw CoachTimelineStoreError.eventNotFound(id)
        }

        try repository.updateStatus(id: id, status: .superseded)

        var replacement = newEvent
        if replacement.supersedesEventId != id {
            replacement = CoachTimelineEvent(
                id: replacement.id,
                type: replacement.type,
                source: replacement.source,
                sourceAttribution: replacement.sourceAttribution,
                confidence: replacement.confidence,
                status: replacement.status,
                payload: replacement.payload,
                utcTimestamp: replacement.utcTimestamp,
                localTimestamp: replacement.localTimestamp,
                timezoneIdentifier: replacement.timezoneIdentifier,
                localDate: replacement.localDate,
                link: replacement.link,
                supersedesEventId: id,
                recordedAt: replacement.recordedAt
            )
        }

        try repository.appendIdempotent(replacement, userId: userId)
    }

    func deleteEventsOlderThan(policy: CoachTimelineCompactionPolicy) async throws {
        guard FormaSwiftDataMigrationGate.shouldAllowCoachDataMaintenance() else { return }
        _ = try repository.deleteEventsOlderThan(
            policy: policy,
            userId: userIdProvider(),
            calendar: calendar
        )
    }

    #if DEBUG
    /// Removes low-value system timeline rows for a day. Never deletes confirmed food/water/weight logs.
    func deleteDebugArtifactEvents(forLocalDate localDate: String) async throws -> Int {
        let debugTypes: Set<CoachTimelineEventType> = [
            .systemRefresh,
            .contextGenerated,
            .healthDataUnavailable
        ]

        let events = try await events(forLocalDate: localDate)
        let ids = Set(
            events
                .filter { debugTypes.contains($0.type) }
                .map(\.id)
        )
        guard !ids.isEmpty else { return 0 }
        return try repository.deleteEvents(withIDs: ids, userId: userIdProvider())
    }
    #endif

    private static func localDateString(for date: Date, calendar: Calendar) -> String {
        CoachTimelineEvent.makeTimestamps(from: date, calendar: calendar).localDate
    }
}
