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

    private var harness: FakeAccountSyncCoordinator.Harness!
    private var coordinator: AccountSyncCoordinator!
    private var uploader: MockAccountSyncUploader!
    private var puller: MockAccountSyncPuller!
    private var networkChecker: MockAccountSyncNetworkChecker!

    private let ownerUID = "userA"

    override func setUp() async throws {
        try await super.setUp()
        harness = FakeAccountSyncCoordinator.makeHarness(uid: ownerUID)
        coordinator = harness.coordinator
        uploader = harness.uploader
        puller = harness.puller
        networkChecker = harness.networkChecker
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
        harness.uidProvider.setUID("other-user")

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

        let uploaded = await AsyncTestSupport.waitUntilWallClock(timeout: 1.0) {
            uploader.uploadCallCount == 1
        }
        XCTAssertTrue(uploaded)
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

        harness.uidProvider.setUID("userB")
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
