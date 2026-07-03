//
//  CoachTimelineQuery.swift
//  Fitness Coach
//
//  Forma — Read filters for Coach timeline stores and context builders.
//

import Foundation

/// Parameters for querying a persisted or in-memory Coach timeline.
struct CoachTimelineQuery: Codable, Equatable, Sendable {

    /// Inclusive lower bound on `localDate` (`yyyy-MM-dd`).
    var fromLocalDate: String?

    /// Inclusive upper bound on `localDate` (`yyyy-MM-dd`).
    var toLocalDate: String?

    /// Restrict to specific event types. `nil` means all types.
    var types: [CoachTimelineEventType]?

    /// Restrict to specific statuses. `nil` means all statuses.
    var statuses: [CoachTimelineEventStatus]?

    /// Restrict to specific origin channels. `nil` means all sources.
    var sources: [CoachTimelineEventSource]?

    /// Restrict to specific pipeline attributions. `nil` means all attributions.
    var sourceAttributions: [CoachTimelineEventSourceAttribution]?

    /// Maximum number of events to return after filtering (most recent first when `nil` sort applied by store).
    var limit: Int?

    /// When `false`, events with status `.superseded` are excluded.
    var includeSuperseded: Bool

    /// When `true`, only events with a `linkedMessageId` are returned.
    var chatLinkedOnly: Bool

    /// When `true`, only events with a `linkedEntryId` are returned.
    var entryLinkedOnly: Bool

    init(
        fromLocalDate: String? = nil,
        toLocalDate: String? = nil,
        types: [CoachTimelineEventType]? = nil,
        statuses: [CoachTimelineEventStatus]? = nil,
        sources: [CoachTimelineEventSource]? = nil,
        sourceAttributions: [CoachTimelineEventSourceAttribution]? = nil,
        limit: Int? = nil,
        includeSuperseded: Bool = false,
        chatLinkedOnly: Bool = false,
        entryLinkedOnly: Bool = false
    ) {
        self.fromLocalDate = fromLocalDate
        self.toLocalDate = toLocalDate
        self.types = types
        self.statuses = statuses
        self.sources = sources
        self.sourceAttributions = sourceAttributions
        self.limit = limit
        self.includeSuperseded = includeSuperseded
        self.chatLinkedOnly = chatLinkedOnly
        self.entryLinkedOnly = entryLinkedOnly
    }
}

extension CoachTimelineQuery {

    /// Default lookback query for AI context assembly (7 calendar days, no superseded).
    static var defaultContextLookback: CoachTimelineQuery {
        CoachTimelineQuery(
            limit: nil,
            includeSuperseded: false
        )
    }

    /// Returns whether `event` satisfies this query (excluding `limit`).
    func matches(_ event: CoachTimelineEvent) -> Bool {
        if let fromLocalDate, event.localDate < fromLocalDate { return false }
        if let toLocalDate, event.localDate > toLocalDate { return false }

        if let types, !types.contains(event.type) { return false }
        if let statuses, !statuses.contains(event.status) { return false }
        if let sources, !sources.contains(event.source) { return false }
        if let sourceAttributions, !sourceAttributions.contains(event.sourceAttribution) { return false }

        if !includeSuperseded, event.status == .superseded { return false }
        if chatLinkedOnly, event.linkedMessageId == nil { return false }
        if entryLinkedOnly, event.linkedEntryId == nil { return false }

        return true
    }

    /// Filters and optionally limits events (most recent `utcTimestamp` first when limiting).
    func apply(to events: [CoachTimelineEvent]) -> [CoachTimelineEvent] {
        var filtered = events.filter { matches($0) }
        filtered.sort { $0.utcTimestamp > $1.utcTimestamp }

        if let limit, filtered.count > limit {
            filtered = Array(filtered.prefix(limit))
        }

        return filtered
    }
}
