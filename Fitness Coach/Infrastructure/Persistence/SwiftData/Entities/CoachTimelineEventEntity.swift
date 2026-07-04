//
//  CoachTimelineEventEntity.swift
//  Fitness Coach
//
//  Forma — SwiftData persistence for Coach Timeline v2 events.
//
//  Stores compact metadata and JSON payloads only. Never stores image bytes,
//  API tokens, or HealthKit sample payloads.
//

import Foundation
import SwiftData

@Model
final class CoachTimelineEventEntity {

    #Index<CoachTimelineEventEntity>(
        [\.localDate],
        [\.utcCreatedAt],
        [\.eventTypeRaw],
        [\.linkedEntryId]
    )

    // MARK: Identity

    @Attribute(.unique) var id: UUID

    /// Firebase / profile owner UID when available.
    var userId: String?

    // MARK: Classification

    var eventTypeRaw: String
    var sourceRaw: String
    var statusRaw: String
    var confidenceRaw: String?
    var sourceAttributionRaw: String?

    // MARK: Timestamps

    var utcCreatedAt: Date
    /// ISO-8601 wall-clock timestamp in the user's timezone at occurrence.
    var localCreatedAt: String
    /// Calendar day key (`yyyy-MM-dd`) in `timezoneIdentifier`.
    var localDate: String
    var timezoneIdentifier: String

    // MARK: Content

    /// Compact human-readable summary for lists and decode fallbacks.
    var summary: String
    /// JSON envelope for structured payload + extended link fields.
    var payloadJSON: String

    // MARK: Links

    var linkedEntryId: UUID?
    var linkedMessageId: UUID?
    var supersedesEventId: UUID?

    // MARK: Versioning

    /// Envelope schema version for `payloadJSON` decoding.
    var schemaVersion: Int

    // MARK: Bookkeeping

    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID,
        userId: String?,
        eventTypeRaw: String,
        sourceRaw: String,
        statusRaw: String,
        confidenceRaw: String?,
        sourceAttributionRaw: String?,
        utcCreatedAt: Date,
        localCreatedAt: String,
        localDate: String,
        timezoneIdentifier: String,
        summary: String,
        payloadJSON: String,
        linkedEntryId: UUID?,
        linkedMessageId: UUID?,
        supersedesEventId: UUID?,
        schemaVersion: Int,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.userId = userId
        self.eventTypeRaw = eventTypeRaw
        self.sourceRaw = sourceRaw
        self.statusRaw = statusRaw
        self.confidenceRaw = confidenceRaw
        self.sourceAttributionRaw = sourceAttributionRaw
        self.utcCreatedAt = utcCreatedAt
        self.localCreatedAt = localCreatedAt
        self.localDate = localDate
        self.timezoneIdentifier = timezoneIdentifier
        self.summary = summary
        self.payloadJSON = payloadJSON
        self.linkedEntryId = linkedEntryId
        self.linkedMessageId = linkedMessageId
        self.supersedesEventId = supersedesEventId
        self.schemaVersion = schemaVersion
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension CoachTimelineEventEntity {

    static let currentSchemaVersion = 1
}
