//
//  CoachTimelineCompactionPolicy.swift
//  Fitness Coach
//
//  Forma — Rules for trimming and summarizing persisted Coach timeline events.
//

import Foundation

/// Policy controlling retention and compaction of timeline events.
///
/// Compaction never mutates canonical log SSOT (food/water/weight entries);
/// it only reduces timeline event volume for storage and AI context cost.
struct CoachTimelineCompactionPolicy: Codable, Equatable, Sendable {

    /// Maximum events retained per calendar day after compaction.
    var maxEventsPerDay: Int

    /// Number of calendar days to retain in the hot timeline store.
    var retainDays: Int

    /// Event types that may collapse into a single summary event per day.
    var collapsibleTypes: [CoachTimelineEventType]

    /// When `true`, mutation-confirmed events are never removed (only superseded).
    var preserveConfirmedMutations: Bool

    /// When `true`, failed and rejected events older than `retainDays` may be dropped.
    var dropStaleFailures: Bool

    /// Minimum events to keep per day even when over `maxEventsPerDay`.
    var minimumEventsPerDay: Int

    init(
        maxEventsPerDay: Int = 200,
        retainDays: Int = 30,
        collapsibleTypes: [CoachTimelineEventType] = [
            .stepsUpdated,
            .systemRefresh,
            .contextGenerated,
            .healthDataUnavailable
        ],
        preserveConfirmedMutations: Bool = true,
        dropStaleFailures: Bool = true,
        minimumEventsPerDay: Int = 8
    ) {
        self.maxEventsPerDay = maxEventsPerDay
        self.retainDays = retainDays
        self.collapsibleTypes = collapsibleTypes
        self.preserveConfirmedMutations = preserveConfirmedMutations
        self.dropStaleFailures = dropStaleFailures
        self.minimumEventsPerDay = minimumEventsPerDay
    }
}

extension CoachTimelineCompactionPolicy {

    /// Conservative defaults for production Coach timeline storage.
    static let `default` = CoachTimelineCompactionPolicy()

    /// Aggressive compaction for AI context export (smaller payload).
    static let aiContextExport = CoachTimelineCompactionPolicy(
        maxEventsPerDay: 40,
        retainDays: 7,
        collapsibleTypes: [
            .stepsUpdated,
            .systemRefresh,
            .contextGenerated,
            .healthDataUnavailable,
            .workoutDetected
        ],
        preserveConfirmedMutations: true,
        dropStaleFailures: true,
        minimumEventsPerDay: 4
    )

    func isCollapsible(_ type: CoachTimelineEventType) -> Bool {
        collapsibleTypes.contains(type)
    }

    func shouldPreserve(_ event: CoachTimelineEvent) -> Bool {
        if preserveConfirmedMutations,
           event.status == .confirmed,
           isMutationEvent(event.type) {
            return true
        }
        return false
    }

    private func isMutationEvent(_ type: CoachTimelineEventType) -> Bool {
        switch type {
        case .foodLogged, .foodEdited, .foodDeleted, .waterLogged, .weightLogged, .undoPerformed,
             .pendingConfirmationConfirmed:
            return true
        default:
            return false
        }
    }
}
