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
        try repository.appendIdempotent(event, userId: userIdProvider())
    }

    func appendMany(_ events: [CoachTimelineEvent]) async throws {
        try repository.appendManyIdempotent(events, userId: userIdProvider())
    }

    func events(forLocalDate localDate: String) async throws -> [CoachTimelineEvent] {
        var query = CoachTimelineQuery(
            fromLocalDate: localDate,
            toLocalDate: localDate,
            includeSuperseded: false
        )
        query.limit = nil
        return try repository.fetch(query: query, userId: userIdProvider())
    }

    func events(from start: Date, to end: Date) async throws -> [CoachTimelineEvent] {
        guard start <= end else {
            throw CoachTimelineStoreError.invalidDateRange
        }

        let all = try repository.fetch(
            query: CoachTimelineQuery(includeSuperseded: false),
            userId: userIdProvider()
        )
        return all.filter { event in
            event.utcTimestamp >= start && event.utcTimestamp <= end
        }
    }

    func recentEvents(limit: Int, before date: Date?) async throws -> [CoachTimelineEvent] {
        guard limit > 0 else { return [] }

        let all = try repository.fetch(
            query: CoachTimelineQuery(includeSuperseded: false),
            userId: userIdProvider()
        )

        let filtered = all.filter { event in
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
        guard try repository.entity(id: id) != nil else {
            throw CoachTimelineStoreError.eventNotFound(id)
        }
        try repository.updateStatus(id: id, status: status)
    }

    func supersedeEvent(id: UUID, by newEvent: CoachTimelineEvent) async throws {
        guard try repository.entity(id: id) != nil else {
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

        try repository.appendIdempotent(replacement, userId: userIdProvider())
    }

    func deleteEventsOlderThan(policy: CoachTimelineCompactionPolicy) async throws {
        _ = try repository.deleteEventsOlderThan(
            policy: policy,
            userId: userIdProvider(),
            calendar: calendar
        )
    }
}
