//
//  CoachTimelineDay.swift
//  Fitness Coach
//
//  Forma — Calendar-day grouping of Coach timeline events.
//

import Foundation

/// Events grouped by `localDate` in a specific timezone.
///
/// Days are the primary unit for UI timelines and AI context compaction.
struct CoachTimelineDay: Codable, Equatable, Identifiable, Sendable {

    /// Same as `localDate` — stable key for persistence and queries.
    var id: String { localDate }

    /// Calendar day key (`yyyy-MM-dd`) in `timezoneIdentifier`.
    let localDate: String

    /// IANA timezone used when bucketing events into this day.
    let timezoneIdentifier: String

    /// Events on this day, typically sorted by `utcTimestamp` ascending.
    var events: [CoachTimelineEvent]

    init(
        localDate: String,
        timezoneIdentifier: String,
        events: [CoachTimelineEvent] = []
    ) {
        self.localDate = localDate
        self.timezoneIdentifier = timezoneIdentifier
        self.events = events
    }
}

extension CoachTimelineDay {

    /// Groups events by `localDate`, preserving insertion order within each day.
    static func group(
        _ events: [CoachTimelineEvent],
        sortAscending: Bool = true
    ) -> [CoachTimelineDay] {
        let grouped = Dictionary(grouping: events, by: \.localDate)
        let sortedDates = grouped.keys.sorted()

        return sortedDates.map { localDate in
            let dayEvents = grouped[localDate] ?? []
            let timezoneIdentifier = dayEvents.first?.timezoneIdentifier ?? TimeZone.current.identifier
            let sortedEvents = dayEvents.sorted {
                sortAscending
                    ? $0.utcTimestamp < $1.utcTimestamp
                    : $0.utcTimestamp > $1.utcTimestamp
            }
            return CoachTimelineDay(
                localDate: localDate,
                timezoneIdentifier: timezoneIdentifier,
                events: sortedEvents
            )
        }
    }
}
