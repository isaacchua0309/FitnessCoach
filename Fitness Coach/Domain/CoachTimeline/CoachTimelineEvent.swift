//
//  CoachTimelineEvent.swift
//  Fitness Coach
//
//  Forma — Atomic persisted fact in the Coach event timeline.
//
//  `CoachTimelineEvent` is the model-visible unit for user actions, assistant
//  replies, mutations, photo analysis, Health activity, and system signals.
//  It is designed for SwiftData persistence and AI context compaction.
//

import Foundation

/// A single immutable-friendly record in the Coach event timeline.
struct CoachTimelineEvent: Codable, Identifiable, Equatable, Sendable {

    // MARK: Identity

    /// Stable identifier for this timeline event.
    let id: UUID

    // MARK: Classification

    let type: CoachTimelineEventType
    let source: CoachTimelineEventSource
    let sourceAttribution: CoachTimelineEventSourceAttribution

    /// Optional confidence for estimates and detections.
    var confidence: CoachTimelineEventConfidence?

    /// Lifecycle status relative to confirmation and corrections.
    var status: CoachTimelineEventStatus

    /// Structured, persistence-safe payload for `type`.
    let payload: CoachTimelineEventPayload

    // MARK: Timestamps

    /// Canonical instant when the underlying action occurred (UTC).
    let utcTimestamp: Date

    /// Wall-clock timestamp in the user's timezone, ISO-8601 with offset.
    let localTimestamp: String

    /// IANA timezone identifier active when the event was recorded.
    let timezoneIdentifier: String

    /// Calendar day key (`yyyy-MM-dd`) in `timezoneIdentifier` for grouping.
    let localDate: String

    // MARK: Links & corrections

    /// Cross-links to chat messages, log entries, and photo sessions.
    let link: CoachTimelineEventLink

    /// When this event replaces a prior event (edit, delete, recommission).
    let supersedesEventId: UUID?

    /// When the event was appended to the timeline store (may differ from `utcTimestamp`).
    let recordedAt: Date

    init(
        id: UUID = UUID(),
        type: CoachTimelineEventType,
        source: CoachTimelineEventSource,
        sourceAttribution: CoachTimelineEventSourceAttribution,
        confidence: CoachTimelineEventConfidence? = nil,
        status: CoachTimelineEventStatus,
        payload: CoachTimelineEventPayload,
        utcTimestamp: Date,
        localTimestamp: String,
        timezoneIdentifier: String,
        localDate: String,
        link: CoachTimelineEventLink = CoachTimelineEventLink(),
        supersedesEventId: UUID? = nil,
        recordedAt: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.source = source
        self.sourceAttribution = sourceAttribution
        self.confidence = confidence
        self.status = status
        self.payload = payload
        self.utcTimestamp = utcTimestamp
        self.localTimestamp = localTimestamp
        self.timezoneIdentifier = timezoneIdentifier
        self.localDate = localDate
        self.link = link
        self.supersedesEventId = supersedesEventId
        self.recordedAt = recordedAt
    }
}

// MARK: - Timestamp helpers

extension CoachTimelineEvent {

    /// Builds UTC and local timestamp fields from an absolute instant.
    static func makeTimestamps(
        from instant: Date = Date(),
        calendar: Calendar = .current
    ) -> (utc: Date, localISO8601: String, timezoneIdentifier: String, localDate: String) {
        let timezone = calendar.timeZone
        let timezoneIdentifier = timezone.identifier

        let localFormatter = ISO8601DateFormatter()
        localFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        localFormatter.timeZone = timezone

        let dayFormatter = DateFormatter()
        dayFormatter.calendar = calendar
        dayFormatter.locale = Locale(identifier: "en_US_POSIX")
        dayFormatter.timeZone = timezone
        dayFormatter.dateFormat = "yyyy-MM-dd"

        return (
            utc: instant,
            localISO8601: localFormatter.string(from: instant),
            timezoneIdentifier: timezoneIdentifier,
            localDate: dayFormatter.string(from: instant)
        )
    }

    /// Convenience factory with computed timestamp fields.
    static func make(
        id: UUID = UUID(),
        type: CoachTimelineEventType,
        source: CoachTimelineEventSource,
        sourceAttribution: CoachTimelineEventSourceAttribution,
        confidence: CoachTimelineEventConfidence? = nil,
        status: CoachTimelineEventStatus,
        payload: CoachTimelineEventPayload,
        occurredAt: Date = Date(),
        calendar: Calendar = .current,
        link: CoachTimelineEventLink = CoachTimelineEventLink(),
        supersedesEventId: UUID? = nil,
        recordedAt: Date = Date()
    ) -> CoachTimelineEvent {
        let timestamps = makeTimestamps(from: occurredAt, calendar: calendar)
        return CoachTimelineEvent(
            id: id,
            type: type,
            source: source,
            sourceAttribution: sourceAttribution,
            confidence: confidence,
            status: status,
            payload: payload,
            utcTimestamp: timestamps.utc,
            localTimestamp: timestamps.localISO8601,
            timezoneIdentifier: timestamps.timezoneIdentifier,
            localDate: timestamps.localDate,
            link: link,
            supersedesEventId: supersedesEventId,
            recordedAt: recordedAt
        )
    }
}

// MARK: - Link accessors

extension CoachTimelineEvent {

    var linkedEntryId: UUID? { link.linkedEntryId }
    var linkedMessageId: UUID? { link.linkedMessageId }
}
