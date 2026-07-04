//
//  CoachTimelineEventLink.swift
//  Fitness Coach
//
//  Forma — Cross-entity links between timeline events and app records.
//

import Foundation

/// Stable links from a timeline event to chat, log, and session records.
///
/// Links are optional because not every event maps to a persisted entry or
/// message (e.g. `healthDataUnavailable`, `systemRefresh`).
struct CoachTimelineEventLink: Codable, Equatable, Sendable {

    /// Food, water, or weight entry affected by this event.
    var linkedEntryId: UUID?
    /// Chat transcript message (`ChatMessage.id`) when applicable.
    var linkedMessageId: UUID?
    /// Meal photo analysis session (`ImageAnalysisSession.sessionId`).
    var linkedPhotoSessionId: UUID?
    /// Daily log day bucket when known.
    var linkedDailyLogId: UUID?
    /// Additional related timeline events (e.g. estimate → log chain).
    var relatedEventIds: [UUID]

    init(
        linkedEntryId: UUID? = nil,
        linkedMessageId: UUID? = nil,
        linkedPhotoSessionId: UUID? = nil,
        linkedDailyLogId: UUID? = nil,
        relatedEventIds: [UUID] = []
    ) {
        self.linkedEntryId = linkedEntryId
        self.linkedMessageId = linkedMessageId
        self.linkedPhotoSessionId = linkedPhotoSessionId
        self.linkedDailyLogId = linkedDailyLogId
        self.relatedEventIds = relatedEventIds
    }
}
