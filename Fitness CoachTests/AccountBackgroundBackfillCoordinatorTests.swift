//
//  AccountBackgroundBackfillCoordinatorTests.swift
//  Fitness CoachTests
//
//  Forma — Background backfill scheduling and refresh notification (Phase 4).
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class AccountBackgroundBackfillCoordinatorTests: XCTestCase {

    func testRunBackgroundBackfillNotifiesOnCompletion() async throws {
        let harness = try BackgroundBackfillCoordinatorHarness.make()
        harness.restoreEnabled = true
        harness.stateStore.markCompleted(
            uid: harness.ownerUID,
            summary: harness.completedBlockingSummary(),
            now: harness.referenceDate
        )

        await harness.coordinator.runBackgroundBackfillIfNeeded(uid: harness.ownerUID)

        XCTAssertEqual(harness.finishedBackfillCount, 1)
    }

    func testRunBackgroundBackfillDoesNotNotifyWhenSkipped() async {
        let harness = try! BackgroundBackfillCoordinatorHarness.make()
        harness.restoreEnabled = true

        await harness.coordinator.runBackgroundBackfillIfNeeded(uid: harness.ownerUID)

        XCTAssertEqual(harness.finishedBackfillCount, 0)
    }
}

@MainActor
private final class BackgroundBackfillCoordinatorHarness {

    let ownerUID = "user-a"
    let referenceDate = ProfileFixtures.referenceDate
    let stateStore: AccountRestoreStateStore
    let coordinator: AccountRestoreCoordinator
    private let counter: BackfillCounter

    var restoreEnabled: Bool {
        get { BackgroundBackfillFeatureGate.isRestoreEnabled }
        set { BackgroundBackfillFeatureGate.isRestoreEnabled = newValue }
    }

    static func make() throws -> BackgroundBackfillCoordinatorHarness {
        let defaults = UserDefaults(suiteName: "AccountBackgroundBackfillCoordinatorTests.\(UUID().uuidString)")!
        let dateProvider = FixedDailyLogTestDateProvider(now: ProfileFixtures.referenceDate)
        let container = try FormaModelContainer.makeContainer(inMemory: true)
        let store = SwiftDataStore(container: container)
        let profileService = UserProfileService(store: store, dateProvider: dateProvider)
        let stateStore = AccountRestoreStateStore(userDefaults: defaults)
        let localInspector = AccountLocalDataInspector(
            store: store,
            userProfileService: profileService,
            outboxStore: SwiftDataAccountSyncOutboxStore(store: store),
            dateProvider: dateProvider
        )
        let remoteInspector = BackgroundStubRemoteInspector()
        let currentUIDBox = CurrentUIDBox(uid: "user-a")
        let counter = BackfillCounter()
        let initialRestore = RecordingBackgroundBackfillService(referenceDate: ProfileFixtures.referenceDate)
        let coordinator = AccountRestoreCoordinator(
            namespaceService: AccountDataNamespaceService(
                store: store,
                healthCacheStore: LocalHealthCacheStore(),
                userDefaults: defaults,
                syncCoordinator: BackgroundRecordingSyncCoordinator()
            ),
            migrationService: AccountMigrationService(
                store: store,
                userProfileService: profileService,
                uidProvider: ClosureAccountUIDProvider { currentUIDBox.uid }
            ),
            localInspector: localInspector,
            remoteInspector: remoteInspector,
            initialRestoreService: initialRestore,
            stateStore: stateStore,
            syncCoordinator: BackgroundRecordingSyncCoordinator(),
            currentUIDProvider: { currentUIDBox.uid },
            restoreEnabledProvider: { BackgroundBackfillFeatureGate.isRestoreEnabled },
            dateProvider: dateProvider,
            onBackgroundBackfillFinished: { _ in
                counter.value += 1
            }
        )
        return BackgroundBackfillCoordinatorHarness(
            stateStore: stateStore,
            coordinator: coordinator,
            counter: counter
        )
    }

    private init(
        stateStore: AccountRestoreStateStore,
        coordinator: AccountRestoreCoordinator,
        counter: BackfillCounter
    ) {
        self.stateStore = stateStore
        self.coordinator = coordinator
        self.counter = counter
    }

    var finishedBackfillCount: Int { counter.value }

    func completedBlockingSummary() -> AccountRestoreSummary {
        AccountRestoreSummary(
            uid: ownerUID,
            reason: .afterSignIn,
            mode: .blockingInitial,
            status: .completed,
            startedAt: referenceDate,
            endedAt: referenceDate,
            profileRestored: true,
            dailyLogsRestored: 1,
            foodEntriesRestored: 1,
            waterEntriesRestored: 0,
            weightEntriesRestored: 0,
            dailyReviewsRestored: 0,
            skippedLocalNewer: 0,
            conflicts: 0,
            failed: 0,
            isPartial: false,
            userFacingMessage: nil
        )
    }
}

private enum BackgroundBackfillFeatureGate {
    static var isRestoreEnabled = false
}

private final class BackfillCounter {
    var value = 0
}

private final class CurrentUIDBox {
    var uid: String
    init(uid: String) { self.uid = uid }
}

@MainActor
private final class RecordingBackgroundBackfillService: AccountInitialRestoring {
    private let referenceDate: Date

    init(referenceDate: Date) {
        self.referenceDate = referenceDate
    }

    func runBlockingInitialRestore(
        uid: String,
        reason: AccountRestoreReason
    ) async -> AccountRestoreSummary {
        skippedSummary(uid: uid, reason: reason)
    }

    func runBackgroundBackfill(
        uid: String,
        reason: AccountRestoreReason
    ) async -> AccountRestoreSummary {
        AccountRestoreSummary(
            uid: uid,
            reason: reason,
            mode: .backgroundBackfill,
            status: .completed,
            startedAt: referenceDate,
            endedAt: referenceDate,
            profileRestored: true,
            dailyLogsRestored: 2,
            foodEntriesRestored: 1,
            waterEntriesRestored: 0,
            weightEntriesRestored: 0,
            dailyReviewsRestored: 0,
            skippedLocalNewer: 0,
            conflicts: 0,
            failed: 0,
            isPartial: false,
            userFacingMessage: nil
        )
    }

    private func skippedSummary(uid: String, reason: AccountRestoreReason) -> AccountRestoreSummary {
        AccountRestoreSummary(
            uid: uid,
            reason: reason,
            mode: .backgroundBackfill,
            status: .skipped,
            startedAt: referenceDate,
            endedAt: referenceDate,
            profileRestored: false,
            dailyLogsRestored: 0,
            foodEntriesRestored: 0,
            waterEntriesRestored: 0,
            weightEntriesRestored: 0,
            dailyReviewsRestored: 0,
            skippedLocalNewer: 0,
            conflicts: 0,
            failed: 0,
            isPartial: false,
            userFacingMessage: nil
        )
    }
}

private struct BackgroundStubRemoteInspector: AccountRemoteDataInspecting {
    func inspectRemoteData(for uid: String, today: Date) async -> AccountRemoteDataStatus {
        AccountRemoteDataStatus(
            uid: uid,
            hasCloudProfile: false,
            hasRecentDailyLogs: false,
            hasRecentFoodEntries: false,
            hasRecentWaterEntries: false,
            hasWeightHistory: false,
            hasDailyReviews: false,
            hasAnyRestorableData: false,
            newestRemoteUpdatedAt: nil,
            failure: nil
        )
    }
}

@MainActor
private final class BackgroundRecordingSyncCoordinator: AccountSyncCoordinating {
    func syncNow(for uid: String, reason: AccountSyncReason) async -> AccountSyncRunSummary {
        AccountSyncRunSummary(
            uid: uid, reason: reason, startedAt: Date(), endedAt: Date(),
            uploadSummary: nil, pullSummary: nil, didSkip: true, skipReason: nil
        )
    }
    func uploadPendingOnly(for uid: String, reason: AccountSyncReason) async -> AccountSyncRunSummary {
        await syncNow(for: uid, reason: reason)
    }
    func pullRecentOnly(for uid: String, reason: AccountSyncReason) async -> AccountSyncRunSummary {
        await syncNow(for: uid, reason: reason)
    }
    func cancelPendingWork() {}
}
