//
//  CoachTimelinePruningPolicy.swift
//  Fitness Coach
//
//  Forma — SwiftData retention rules for persisted Coach timeline events.
//

import Foundation

/// Disk retention policy for `CoachTimelineEventEntity` rows.
///
/// Pruning never deletes canonical food/water/weight log SSOT — only timeline
/// event rows. Same-day events are always preserved.
struct CoachTimelinePruningPolicy: Codable, Equatable, Sendable {

    /// Minimum number of calendar days of detailed events to retain.
    var detailedRetentionDays: Int

    /// When `true`, replace batches of pruned collapsible events with one compact summary row per day.
    var writeCompactSummaries: Bool

    /// Event types eligible for pruning and summary compaction beyond retention.
    var collapsibleTypes: [CoachTimelineEventType]

    /// When `true`, confirmed mutation events are kept beyond the retention window.
    var preserveConfirmedMutations: Bool

    /// When `true`, failed/rejected rows older than retention may be removed.
    var dropStaleFailures: Bool

    init(
        detailedRetentionDays: Int = 30,
        writeCompactSummaries: Bool = true,
        collapsibleTypes: [CoachTimelineEventType] = [
            .stepsUpdated,
            .systemRefresh,
            .contextGenerated,
            .healthDataUnavailable
        ],
        preserveConfirmedMutations: Bool = true,
        dropStaleFailures: Bool = true
    ) {
        self.detailedRetentionDays = detailedRetentionDays
        self.writeCompactSummaries = writeCompactSummaries
        self.collapsibleTypes = collapsibleTypes
        self.preserveConfirmedMutations = preserveConfirmedMutations
        self.dropStaleFailures = dropStaleFailures
    }
}

extension CoachTimelinePruningPolicy {

    static let `default` = CoachTimelinePruningPolicy()

    func isCollapsible(_ type: CoachTimelineEventType) -> Bool {
        collapsibleTypes.contains(type)
    }

    func shouldNeverPrune(localDate: String, todayLocalDate: String) -> Bool {
        localDate == todayLocalDate
    }
}
