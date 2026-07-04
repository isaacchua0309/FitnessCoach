//
//  AccountRestoreStateStoreTests.swift
//  Fitness CoachTests
//
//  Forma — Account restore state store tests (Phase 4).
//

import XCTest
@testable import Fitness_Coach

final class AccountRestoreStateStoreTests: XCTestCase {

    private let uidA = "user-a"
    private let uidB = "user-b"
    private let referenceDate = ProfileTestFixtures.referenceDate
    private let appVersion = "9.9.9"
    private let schemaVersion = 42

    private var defaults: UserDefaults!
    private var store: AccountRestoreStateStore!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "AccountRestoreStateStoreTests.\(UUID().uuidString)")!
        store = AccountRestoreStateStore(
            userDefaults: defaults,
            schemaVersionProvider: { self.schemaVersion },
            appVersionProvider: { self.appVersion }
        )
    }

    override func tearDown() {
        store = nil
        defaults.removePersistentDomain(forName: defaults.suiteName!)
        defaults = nil
        super.tearDown()
    }

    func testLoadStateDefaultsToNotStartedForUnknownUID() {
        let state = store.loadState(uid: uidA)

        XCTAssertEqual(state.uid, uidA)
        XCTAssertEqual(state.status, .notStarted)
        XCTAssertNil(state.lastStartedAt)
        XCTAssertNil(state.lastCompletedAt)
        XCTAssertNil(state.lastSuccessfulBlockingRestoreAt)
        XCTAssertNil(state.lastSuccessfulBackgroundBackfillAt)
        XCTAssertNil(state.lastFailureMessage)
        XCTAssertNil(state.restoredSchemaVersion)
        XCTAssertNil(state.lastRestoreAppVersion)
    }

    func testMarkStartedPersistsUIDScopedMetadata() {
        store.markStarted(uid: uidA, reason: .afterSignIn, mode: .blockingInitial, now: referenceDate)

        let state = store.loadState(uid: uidA)
        XCTAssertEqual(state.status, .checking)
        XCTAssertEqual(state.lastStartedAt, referenceDate)
        XCTAssertNil(state.lastFailureMessage)
        XCTAssertEqual(
            defaults.string(forKey: AccountRestoreStateStoreSupport.statusKey(for: uidA)),
            AccountRestoreStatus.checking.rawValue
        )
    }

    func testMarkProgressPersistsInProgressStatus() {
        store.markStarted(uid: uidA, reason: .afterSignIn, mode: .blockingInitial, now: referenceDate)
        store.markProgress(uid: uidA, status: .restoringRecentData, now: referenceDate)

        XCTAssertEqual(store.loadState(uid: uidA).status, .restoringRecentData)
    }

    func testMarkCompletedPersistsBlockingSuccessMetadata() {
        let summary = makeSummary(uid: uidA, mode: .blockingInitial, status: .completed)

        store.markCompleted(uid: uidA, summary: summary, now: referenceDate)

        let state = store.loadState(uid: uidA)
        XCTAssertEqual(state.status, .completed)
        XCTAssertEqual(state.lastCompletedAt, referenceDate)
        XCTAssertEqual(state.lastSuccessfulBlockingRestoreAt, referenceDate)
        XCTAssertNil(state.lastSuccessfulBackgroundBackfillAt)
        XCTAssertNil(state.lastFailureMessage)
        XCTAssertEqual(state.restoredSchemaVersion, schemaVersion)
        XCTAssertEqual(state.lastRestoreAppVersion, appVersion)
    }

    func testMarkCompletedPersistsBackgroundBackfillMetadata() {
        let summary = makeSummary(uid: uidA, mode: .backgroundBackfill, status: .completed)

        store.markCompleted(uid: uidA, summary: summary, now: referenceDate)

        let state = store.loadState(uid: uidA)
        XCTAssertEqual(state.lastSuccessfulBackgroundBackfillAt, referenceDate)
        XCTAssertNil(state.lastSuccessfulBlockingRestoreAt)
    }

    func testMarkPartialIsIdempotentAndRecordsPartialStatus() {
        let summary = makeSummary(uid: uidA, mode: .blockingInitial, status: .partial)

        store.markPartial(uid: uidA, summary: summary, now: referenceDate)
        store.markPartial(uid: uidA, summary: summary, now: referenceDate)

        let state = store.loadState(uid: uidA)
        XCTAssertEqual(state.status, .partial)
        XCTAssertEqual(state.lastSuccessfulBlockingRestoreAt, referenceDate)
    }

    func testMarkOfflineAndFailedPersistTerminalStates() {
        store.markOffline(uid: uidA, reason: .appLaunch, now: referenceDate)
        XCTAssertEqual(store.loadState(uid: uidA).status, .offline)

        store.markFailed(uid: uidA, reason: .manualRetry, message: "Network unavailable", now: referenceDate)
        let failed = store.loadState(uid: uidA)
        XCTAssertEqual(failed.status, .failed)
        XCTAssertEqual(failed.lastFailureMessage, "Network unavailable")
    }

    func testFailureMessageIsSanitizedAndTruncated() {
        let longMessage = String(repeating: "x", count: 300)
        store.markFailed(uid: uidA, reason: .manualRetry, message: longMessage, now: referenceDate)

        let message = store.loadState(uid: uidA).lastFailureMessage
        XCTAssertEqual(message?.count, 240)
    }

    func testStateIsUIDScoped() {
        store.markStarted(uid: uidA, reason: .afterSignIn, mode: .blockingInitial, now: referenceDate)
        store.markCompleted(
            uid: uidB,
            summary: makeSummary(uid: uidB, mode: .blockingInitial, status: .completed),
            now: referenceDate
        )

        XCTAssertEqual(store.loadState(uid: uidA).status, .checking)
        XCTAssertEqual(store.loadState(uid: uidB).status, .completed)
    }

    func testClearOnlyRemovesRequestedUID() {
        store.markCompleted(
            uid: uidA,
            summary: makeSummary(uid: uidA, mode: .blockingInitial, status: .completed),
            now: referenceDate
        )
        store.markCompleted(
            uid: uidB,
            summary: makeSummary(uid: uidB, mode: .blockingInitial, status: .completed),
            now: referenceDate
        )

        store.clear(uid: uidA)

        XCTAssertEqual(store.loadState(uid: uidA).status, .notStarted)
        XCTAssertEqual(store.loadState(uid: uidB).status, .completed)
    }

    func testShouldRunBlockingRestoreWhenLocalDataNeedsInitialRestore() {
        let localStatus = emptyLocalStatus(uid: uidA, needsInitialRestore: true)

        XCTAssertTrue(store.shouldRunBlockingRestore(uid: uidA, localDataStatus: localStatus, now: referenceDate))
    }

    func testShouldNotRunBlockingRestoreWhenLocalDataIsPopulated() {
        let localStatus = emptyLocalStatus(uid: uidA, needsInitialRestore: false)

        XCTAssertFalse(store.shouldRunBlockingRestore(uid: uidA, localDataStatus: localStatus, now: referenceDate))
    }

    func testShouldNotRunBlockingRestoreAfterSuccessfulBlockingRestore() {
        store.markCompleted(
            uid: uidA,
            summary: makeSummary(uid: uidA, mode: .blockingInitial, status: .completed),
            now: referenceDate
        )
        let localStatus = emptyLocalStatus(uid: uidA, needsInitialRestore: true)

        XCTAssertFalse(store.shouldRunBlockingRestore(uid: uidA, localDataStatus: localStatus, now: referenceDate))
    }

    func testShouldRunBackgroundBackfillAfterBlockingRestoreCompletes() {
        store.markCompleted(
            uid: uidA,
            summary: makeSummary(uid: uidA, mode: .blockingInitial, status: .completed),
            now: referenceDate
        )

        XCTAssertTrue(store.shouldRunBackgroundBackfill(uid: uidA, now: referenceDate))
    }

    func testShouldNotRunBackgroundBackfillUntilBlockingRequirementIsSatisfied() {
        XCTAssertFalse(store.shouldRunBackgroundBackfill(uid: uidA, now: referenceDate))
    }

    func testShouldNotRerunBackgroundBackfillWhenAlreadyCompletedAtCurrentVersions() {
        store.markCompleted(
            uid: uidA,
            summary: makeSummary(uid: uidA, mode: .blockingInitial, status: .completed),
            now: referenceDate
        )
        store.markCompleted(
            uid: uidA,
            summary: makeSummary(uid: uidA, mode: .backgroundBackfill, status: .completed),
            now: referenceDate
        )

        XCTAssertFalse(store.shouldRunBackgroundBackfill(uid: uidA, now: referenceDate))
    }

    func testShouldRerunBackgroundBackfillWhenSchemaVersionChanges() {
        store.markCompleted(
            uid: uidA,
            summary: makeSummary(uid: uidA, mode: .blockingInitial, status: .completed),
            now: referenceDate
        )
        store.markCompleted(
            uid: uidA,
            summary: makeSummary(uid: uidA, mode: .backgroundBackfill, status: .completed),
            now: referenceDate
        )

        let upgradedStore = AccountRestoreStateStore(
            userDefaults: defaults,
            schemaVersionProvider: { self.schemaVersion + 1 },
            appVersionProvider: { self.appVersion }
        )

        XCTAssertTrue(upgradedStore.shouldRunBackgroundBackfill(uid: uidA, now: referenceDate))
    }

    func testMarkSkippedPersistsSkippedStatus() {
        store.markSkipped(uid: uidA, reason: .appLaunch, now: referenceDate)

        XCTAssertEqual(store.loadState(uid: uidA).status, .skipped)
        XCTAssertEqual(store.loadState(uid: uidA).lastCompletedAt, referenceDate)
    }

    func testRestoreMetadataDoesNotPersistSensitiveSummaryFields() {
        let summary = AccountRestoreSummary(
            uid: uidA,
            reason: .afterSignIn,
            mode: .blockingInitial,
            status: .completed,
            startedAt: referenceDate,
            endedAt: referenceDate,
            profileRestored: true,
            dailyLogsRestored: 3,
            foodEntriesRestored: 12,
            waterEntriesRestored: 4,
            weightEntriesRestored: 2,
            dailyReviewsRestored: 1,
            skippedLocalNewer: 0,
            conflicts: 0,
            failed: 0,
            isPartial: false,
            userFacingMessage: "Restored chicken salad and 72.4 kg weigh-in"
        )

        store.markCompleted(uid: uidA, summary: summary, now: referenceDate)

        let persistedValues = AccountRestoreStateStoreSupport.allKeys(for: uidA)
            .compactMap { defaults.object(forKey: $0) }
        let joined = persistedValues.map { String(describing: $0) }.joined(separator: "|")
        XCTAssertFalse(joined.contains("chicken"))
        XCTAssertFalse(joined.contains("72.4"))
        XCTAssertFalse(joined.contains("salad"))
    }

    func testPrepareForManualRetryClearsFailureMessage() {
        store.markFailed(uid: uidA, reason: .afterSignIn, message: "Restore failed.", now: referenceDate)

        store.prepareForManualRetry(uid: uidA, now: referenceDate)

        XCTAssertNil(store.loadState(uid: uidA).lastFailureMessage)
    }

    func testShouldRunBackgroundBackfillAfterPartialRestore() {
        store.markPartial(
            uid: uidA,
            summary: makeSummary(uid: uidA, mode: .blockingInitial, status: .partial),
            now: referenceDate
        )

        XCTAssertTrue(
            store.shouldRunBackgroundBackfill(
                uid: uidA,
                now: referenceDate.addingTimeInterval(60)
            )
        )
    }

    // MARK: - Fixtures

    private func makeSummary(
        uid: String,
        mode: AccountRestoreMode,
        status: AccountRestoreStatus
    ) -> AccountRestoreSummary {
        AccountRestoreSummary(
            uid: uid,
            reason: .afterSignIn,
            mode: mode,
            status: status,
            startedAt: referenceDate,
            endedAt: referenceDate,
            profileRestored: true,
            dailyLogsRestored: 1,
            foodEntriesRestored: 2,
            waterEntriesRestored: 1,
            weightEntriesRestored: 1,
            dailyReviewsRestored: 0,
            skippedLocalNewer: 0,
            conflicts: 0,
            failed: 0,
            isPartial: status == .partial,
            userFacingMessage: nil
        )
    }

    private func emptyLocalStatus(uid: String, needsInitialRestore: Bool) -> AccountLocalDataStatus {
        AccountLocalDataStatus(
            uid: uid,
            hasProfile: false,
            hasAnyDailyLogs: false,
            hasTodayDailyLog: false,
            foodEntryCount: 0,
            waterEntryCount: 0,
            weightEntryCount: 0,
            dailyReviewCount: 0,
            pendingMutationCount: 0,
            failedMutationCount: 0,
            newestLocalUpdatedAt: nil,
            oldestLocalDate: nil,
            newestLocalDate: nil,
            isEffectivelyEmpty: needsInitialRestore,
            needsInitialRestore: needsInitialRestore
        )
    }
}
