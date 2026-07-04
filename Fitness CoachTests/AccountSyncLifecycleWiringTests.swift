//
//  AccountSyncLifecycleWiringTests.swift
//  Fitness CoachTests
//
//  Forma — Account sync lifecycle wiring tests (Phase 3).
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class AccountSyncLifecycleWiringTests: XCTestCase {

    private let ownerUID = "test-user-1"
    private let referenceDate = DailyLogServiceTestSupport.referenceNow

    func testLocalFoodMutationEnqueuesOutboxAndSchedulesDebouncedUpload() async throws {
        var context = try makeWiredContext()
        _ = try context.harness.seedProfile(ownerUID: ownerUID)

        _ = try context.actionCenter.logFood(
            DailyLogServiceTestSupport.foodDraft(name: "Lunch", calories: 400),
            date: context.harness.today
        )

        XCTAssertEqual(context.state.scheduleCallCount, 1)

        let outbox = try XCTUnwrap(context.harness.base.accountSyncOutboxStore)
        let due = try await outbox.fetchDueMutations(
            ownerUID: ownerUID,
            limit: 10,
            now: referenceDate
        )
        XCTAssertFalse(due.isEmpty)

        try? await Task.sleep(nanoseconds: 120_000_000)
        await AsyncTestSupport.drainMainActorTasks(maxYields: 30)
    }

    func testAccountSwitchCancelsDebouncedUploadForOldUID() async throws {
        var context = try makeWiredContext()
        _ = try context.harness.seedProfile(ownerUID: ownerUID)

        _ = try context.actionCenter.logFood(
            DailyLogServiceTestSupport.foodDraft(name: "Snack", calories: 200),
            date: context.harness.today
        )

        context.state.currentUID = "other-user"
        context.coordinator.cancelPendingWork()

        try? await Task.sleep(nanoseconds: 120_000_000)
        await AsyncTestSupport.drainMainActorTasks(maxYields: 30)

        let localDate = CloudAccountDataDateCodec.localDateString(
            from: context.harness.today,
            calendar: Calendar(identifier: .gregorian)
        )
        let remoteEntries = try await context.remoteStore.fetchFoodEntries(
            uid: ownerUID,
            localDate: localDate
        )
        XCTAssertEqual(remoteEntries.count, 0)
    }

    func testForegroundSyncRequiresSignedInUID() async throws {
        var context = try makeWiredContext()
        context.state.currentUID = nil

        AccountSyncLifecycle.handleAppForeground(
            coordinator: context.coordinator,
            uidProvider: { context.state.currentUID }
        )

        await AsyncTestSupport.drainMainActorTasks(maxYields: 10)
        XCTAssertEqual(context.uploader.uploadCallCount, 0)
    }

    // MARK: - Harness

    private struct WiredContext {
        let harness: FitnessActionCenterTestSupport.Harness
        let actionCenter: FitnessActionCenter
        let coordinator: AccountSyncCoordinator
        let remoteStore: InMemoryAccountDataRemoteStore
        let uploader: TrackingAccountSyncUploader
        let state: TestSyncState
    }

    private final class TestSyncState {
        var currentUID: String?
        var scheduleCallCount = 0
    }

    private func makeWiredContext() throws -> WiredContext {
        let harness = try FitnessActionCenterTestSupport.makeHarness(
            referenceNow: referenceDate,
            cloudUID: ownerUID
        )
        let remoteStore = InMemoryAccountDataRemoteStore()
        let outbox = try XCTUnwrap(harness.base.accountSyncOutboxStore)
        let payloadBuilder = SwiftDataAccountSyncPayloadBuilder(store: harness.store)
        let uploader = TrackingAccountSyncUploader(
            base: AccountSyncUploader(
                outbox: outbox,
                payloadBuilder: payloadBuilder,
                remoteStore: remoteStore,
                store: harness.store,
                nowProvider: { self.referenceDate }
            )
        )
        let puller = AccountSyncPuller(
            remoteStore: remoteStore,
            store: harness.store,
            nowProvider: { self.referenceDate }
        )

        let state = TestSyncState()
        state.currentUID = ownerUID
        let coordinator = AccountSyncCoordinator(
            uploader: uploader,
            puller: puller,
            currentUIDProvider: { state.currentUID },
            nowProvider: { self.referenceDate },
            debounceInterval: .milliseconds(50)
        )

        let actionCenter = FitnessActionCenter(
            foodLogService: harness.foodLogService,
            waterLogService: harness.waterLogService,
            weightLogService: harness.weightLogService,
            dailyLogService: harness.dailyLogService,
            targetService: harness.targetService,
            userProfileService: harness.profileService,
            reviewService: ReviewService(
                store: harness.store,
                dailyLogService: harness.dailyLogService,
                foodLogService: harness.foodLogService,
                waterLogService: harness.waterLogService,
                weightLogService: harness.weightLogService,
                healthActivityQuery: harness.healthActivityQuery,
                userProfileService: harness.profileService,
                aiService: AIService(llmClient: MockLLMClient()),
                mutationTracker: harness.base.accountLocalMutationTracker
            ),
            refreshCenter: harness.refreshCenter,
            currentUIDProvider: { state.currentUID },
            scheduleAccountSyncAfterMutation: {
                state.scheduleCallCount += 1
                AccountSyncLifecycle.scheduleAfterLocalMutation(
                    coordinator: coordinator,
                    uidProvider: { state.currentUID }
                )
            }
        )

        return WiredContext(
            harness: harness,
            actionCenter: actionCenter,
            coordinator: coordinator,
            remoteStore: remoteStore,
            uploader: uploader,
            state: state
        )
    }
}

@MainActor
private final class TrackingAccountSyncUploader: AccountSyncUploading {

    private let base: AccountSyncUploader
    private(set) var uploadCallCount = 0

    init(base: AccountSyncUploader) {
        self.base = base
    }

    func uploadDueMutations(for uid: String, limit: Int) async -> AccountSyncUploadSummary {
        uploadCallCount += 1
        return await base.uploadDueMutations(for: uid, limit: limit)
    }

    func cancelPendingWork() {}
}
