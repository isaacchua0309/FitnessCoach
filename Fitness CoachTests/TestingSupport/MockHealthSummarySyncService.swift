//
//  MockHealthSummarySyncService.swift
//  Fitness CoachTests
//
//  In-memory HealthSummarySyncServing test double.
//

import Foundation
@testable import Fitness_Coach

final class MockHealthSummarySyncService: HealthSummarySyncServing, @unchecked Sendable {

    private let lock = NSLock()

    private(set) var syncAfterLocalHealthRefreshCallCount = 0
    private(set) var lastSyncAfterLocalHealthRefreshDays = 0
    var syncAfterLocalHealthRefreshDelayNanoseconds: UInt64 = 0

    func syncRecentHealthSummaries(days: Int) async {}

    func syncTodayHealthSummary() async {}

    func syncWeeklyReviewIfAvailable() async {}

    func syncAfterLocalHealthRefresh(days: Int) async {
        if syncAfterLocalHealthRefreshDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: syncAfterLocalHealthRefreshDelayNanoseconds)
        }
        lock.lock()
        syncAfterLocalHealthRefreshCallCount += 1
        lastSyncAfterLocalHealthRefreshDays = days
        lock.unlock()
    }

    func syncOnAppForeground() async {}

    func getRemoteSyncState() async -> HealthSummaryRemoteSyncState {
        .idle
    }

    func reset() {
        lock.lock()
        syncAfterLocalHealthRefreshCallCount = 0
        lastSyncAfterLocalHealthRefreshDays = 0
        syncAfterLocalHealthRefreshDelayNanoseconds = 0
        lock.unlock()
    }
}
