//
//  CoachMutationTimelineContext.swift
//  Fitness Coach
//
//  Timeline metadata passed with confirmed Coach mutations.
//

import Foundation

struct CoachMutationTimelineContext: Sendable, Equatable {
    var pendingConfirmationId: UUID?
    var sourceAttribution: CoachTimelineEventSourceAttribution = .userConfirmation
    var userEditedBeforeConfirm: Bool = false
    var relatedPhotoSessionId: UUID?
    var linkedEntryId: UUID?
    var relatedTimelineEventId: UUID?
}

enum CoachMutationTimelineLookup {

    static func latestFoodMutationEventId(
        forEntryId entryId: UUID,
        store: (any CoachTimelineStoring)?
    ) async -> UUID? {
        guard let store else { return nil }
        let events = (try? await store.recentEvents(limit: 100, before: nil)) ?? []
        return events.last(where: { event in
            event.linkedEntryId == entryId &&
                (event.type == .foodLogged || event.type == .foodEdited)
        })?.id
    }
}
