//
//  AccountSyncCoordinatorTests.swift
//  Fitness CoachTests
//
//  Forma — Account sync coordinator tests (Phase 3).
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class AccountSyncCoordinatorTests: XCTestCase {

    private var uploader: MockAccountSyncUploader!
    private var puller: MockAccountSyncPuller!
    private var networkChecker: MockAccountSyncNetworkChecker!
    private var currentUID: String?
    private var coordinator: AccountSyncCoordinator!

    private let ownerUID = "userA"
    private let referenceDate = ProfileTestFixtures.referenceDate

    override func setUp() async throws {
        try await super.setUp()
        uploader = MockAccountSyncUploader()
        puller = MockAccountSyncPuller()
        networkChecker = MockAccountSyncNetworkChecker()
        currentUID = ownerUID
        coordinator = AccountSyncCoordinator(
            uploader: uploader,
            puller: puller,
            networkChecker: networkChecker,
            currentUIDProvider: { [weak self] in self?.currentUID },
            nowProvider: { self.referenceDate },
            debounceInterval: .milliseconds(50)
        )
    }

    func testCoordinatorDoesNotPullWhenPullRecentFlagDisabled() async {
        let summary = await coordinator.syncNow(for: ownerUID, reason: .manual)

        XCTAssertFalse(summary.didSkip)
        XCTAssertEqual(summary.uploadSummary?.uid, ownerUID)
        XCTAssertEqual(uploader.uploadCallCount, 1)
        XCTAssertNil(summary.pullSummary)
        XCTAssertEqual(puller.pullCallCount, 0)
    }

    func testPullRecentOnlySkipsWhenPullFlagDisabled() async {
        let summary = await coordinator.pullRecentOnly(for: ownerUID, reason: .manual)

        XCTAssertTrue(summary.didSkip)
        XCTAssertEqual(summary.skipReason, AccountSyncCoordinatorSkipReason.pullDisabled)
        XCTAssertEqual(puller.pullCallCount, 0)
    }

    func testCoordinatorSkipsWhenUIDMissing() async {
        let summary = await coordinator.syncNow(for: "   ", reason: .manual)

        XCTAssertTrue(summary.didSkip)
        XCTAssertEqual(summary.skipReason, AccountSyncCoordinatorSkipReason.missingUID)
        XCTAssertEqual(uploader.uploadCallCount, 0)
    }

    func testSkipsWhenCurrentUIDDoesNotMatch() async {
        currentUID = "other-user"

        let summary = await coordinator.syncNow(for: ownerUID, reason: .manual)

        XCTAssertTrue(summary.didSkip)
        XCTAssertEqual(summary.skipReason, AccountSyncCoordinatorSkipReason.uidChanged)
        XCTAssertEqual(uploader.uploadCallCount, 0)
    }

    func testSkipsWhenNetworkUnavailable() async {
        networkChecker.isNetworkAvailable = false

        let summary = await coordinator.syncNow(for: ownerUID, reason: .manual)

        XCTAssertTrue(summary.didSkip)
        XCTAssertEqual(summary.skipReason, AccountSyncCoordinatorSkipReason.networkUnavailable)
        XCTAssertEqual(uploader.uploadCallCount, 0)
    }

    func testCoordinatorPreventsConcurrentRunsForSameUID() async {
        uploader.delayNanoseconds = 200_000_000

        async let first = coordinator.syncNow(for: ownerUID, reason: .manual)
        try? await Task.sleep(nanoseconds: 10_000_000)
        let second = await coordinator.syncNow(for: ownerUID, reason: .manual)
        let firstSummary = await first

        XCTAssertFalse(firstSummary.didSkip)
        XCTAssertTrue(second.didSkip)
        XCTAssertEqual(second.skipReason, AccountSyncCoordinatorSkipReason.syncAlreadyInProgress)
        XCTAssertEqual(uploader.uploadCallCount, 1)
    }

    func testAfterLocalMutationSchedulesDebouncedUpload() async {
        let summary = await coordinator.uploadPendingOnly(for: ownerUID, reason: .afterLocalMutation)

        XCTAssertTrue(summary.didSkip)
        XCTAssertEqual(summary.skipReason, AccountSyncCoordinatorSkipReason.debouncedUploadScheduled)
        XCTAssertEqual(uploader.uploadCallCount, 0)

        try? await Task.sleep(nanoseconds: 120_000_000)

        XCTAssertEqual(uploader.uploadCallCount, 1)
    }

    func testAfterSignInDoesNotPullWhenPullFlagDisabled() async {
        let summary = await coordinator.syncNow(for: ownerUID, reason: .afterSignIn)

        XCTAssertFalse(summary.didSkip)
        XCTAssertEqual(uploader.uploadCallCount, 1)
        XCTAssertNil(summary.pullSummary)
        XCTAssertEqual(puller.pullCallCount, 0)
    }

    func testCoordinatorUploadPendingOnlyProcessesOutbox() async {
        let summary = await coordinator.uploadPendingOnly(for: ownerUID, reason: .manual)

        XCTAssertFalse(summary.didSkip)
        XCTAssertEqual(uploader.uploadCallCount, 1)
        XCTAssertNil(summary.pullSummary)
    }

    func testAccountSwitchCancelsOrIgnoresOldUIDResult() async {
        _ = await coordinator.uploadPendingOnly(for: ownerUID, reason: .afterLocalMutation)
        XCTAssertEqual(uploader.uploadCallCount, 0)

        currentUID = "userB"
        try? await Task.sleep(nanoseconds: 120_000_000)

        XCTAssertEqual(uploader.uploadCallCount, 0)
    }

    func testCancelPendingWorkPreventsDebouncedUpload() async {
        let summary = await coordinator.uploadPendingOnly(for: ownerUID, reason: .afterLocalMutation)
        XCTAssertEqual(summary.skipReason, AccountSyncCoordinatorSkipReason.debouncedUploadScheduled)

        coordinator.cancelPendingWork()

        try? await Task.sleep(nanoseconds: 120_000_000)
        XCTAssertEqual(uploader.uploadCallCount, 0)
    }
}

@MainActor
private final class MockAccountSyncUploader: AccountSyncUploading {

    var uploadCallCount = 0
    var delayNanoseconds: UInt64 = 0

    func uploadDueMutations(for uid: String, limit: Int) async -> AccountSyncUploadSummary {
        uploadCallCount += 1
        if delayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: delayNanoseconds)
        }
        return AccountSyncUploadSummary(
            uid: uid,
            attempted: 0,
            succeeded: 0,
            failed: 0,
            cancelled: 0
        )
    }

    func cancelPendingWork() {}
}

@MainActor
private final class MockAccountSyncPuller: AccountSyncPulling {

    var pullCallCount = 0

    func pullRecentAccountData(
        for uid: String,
        from startDate: String,
        to endDate: String
    ) async -> AccountSyncPullSummary {
        pullCallCount += 1
        return AccountSyncPullSummary(
            uid: uid,
            dailyLogsFetched: 0,
            foodEntriesFetched: 0,
            waterEntriesFetched: 0,
            weightEntriesFetched: 0,
            dailyReviewsFetched: 0,
            inserted: 0,
            updated: 0,
            skippedLocalNewer: 0,
            conflicts: 0,
            failed: 0
        )
    }

    func mergeFetchedDocuments(
        for uid: String,
        dailyLogs: [CloudDailyLogDocument],
        foodEntries: [CloudFoodEntryDocument],
        waterEntries: [CloudWaterEntryDocument],
        weightEntries: [CloudWeightEntryDocument],
        dailyReviews: [CloudDailyReviewDocument]
    ) throws -> AccountSyncMergeBatchResult {
        AccountSyncMergeBatchResult(
            inserted: 0,
            updated: 0,
            deleted: 0,
            skippedLocalNewer: 0,
            conflicts: 0,
            failed: 0
        )
    }

    func cancelPendingWork() {}
}

private final class MockAccountSyncNetworkChecker: AccountSyncNetworkChecking, @unchecked Sendable {
    var isNetworkAvailable = true
}
