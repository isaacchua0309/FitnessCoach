//
//  AccountMigrationBackfillReport.swift
//  Fitness Coach
//
//  Forma — Result of a safe ownership backfill evaluation or run (Phase 1).
//

import Foundation

struct AccountMigrationBackfillReport: Equatable, Sendable {
    let uid: String
    let canBackfill: Bool
    let reason: String
    let dailyLogsUpdated: Int
    let foodEntriesUpdated: Int
    let waterEntriesUpdated: Int
    let weightEntriesUpdated: Int
    let dailyReviewsUpdated: Int
    let coachMessagesUpdated: Int
    let timelineEventsUpdated: Int

    var totalRowsUpdated: Int {
        dailyLogsUpdated
            + foodEntriesUpdated
            + waterEntriesUpdated
            + weightEntriesUpdated
            + dailyReviewsUpdated
            + coachMessagesUpdated
            + timelineEventsUpdated
    }

    static func refused(
        uid: String,
        reason: String
    ) -> AccountMigrationBackfillReport {
        AccountMigrationBackfillReport(
            uid: uid,
            canBackfill: false,
            reason: reason,
            dailyLogsUpdated: 0,
            foodEntriesUpdated: 0,
            waterEntriesUpdated: 0,
            weightEntriesUpdated: 0,
            dailyReviewsUpdated: 0,
            coachMessagesUpdated: 0,
            timelineEventsUpdated: 0
        )
    }
}
