//
//  JourneyCrossDeviceRefreshTests.swift
//  Fitness CoachTests
//
//  Forma — Journey Phase 5 cross-device refresh tests.
//

import Combine
import XCTest
@testable import Fitness_Coach

@MainActor
final class JourneyCrossDeviceRefreshTests: XCTestCase {

    private var harness: FitnessActionCenterTestSupport.Harness!
    private var refreshEventBus: AccountDataRefreshEventBus!
    private var crossDeviceCoordinator: FeatureCrossDeviceSyncCoordinator!
    private var sessionUID: String!
    private let otherUID = "other-user"

    override func setUp() async throws {
        harness = try FitnessActionCenterTestSupport.makeHarness()
        refreshEventBus = AccountDataRefreshEventBus()
        crossDeviceCoordinator = FeatureCrossDeviceSyncCoordinator()
        sessionUID = harness.cloudUID
        _ = try harness.seedProfile(ownerUID: sessionUID)
    }

    override func tearDown() {
        harness = nil
        refreshEventBus = nil
        crossDeviceCoordinator = nil
        sessionUID = nil
        super.tearDown()
    }

    func testJourneyReloadsAfterRemoteFoodChange() async throws {
        let model = makeModel()
        await model.loadProgress()

        guard case .loaded(let initial) = model.viewState else {
            return XCTFail("Expected loaded Journey state")
        }

        _ = try harness.actionCenter.logFood(
            DailyLogServiceTestSupport.foodDraft(name: "Lunch", calories: 500),
            date: harness.today
        )

        try await publishRefresh(domains: [.food])

        guard case .loaded(let updated) = model.viewState else {
            return XCTFail("Expected loaded Journey state after food refresh")
        }
        XCTAssertGreaterThan(
            updated.streaks.currentLoggingStreakDays,
            initial.streaks.currentLoggingStreakDays
        )
    }

    func testJourneyReloadsAfterRemoteWeightChange() async throws {
        let model = makeModel()
        await model.loadProgress()

        guard case .loaded(let initial) = model.viewState else {
            return XCTFail("Expected loaded Journey state")
        }
        XCTAssertNotEqual(initial.baseline.currentWeightKg, 82.5)

        _ = try harness.weightLogService.logWeight(82.5, date: harness.today)

        try await publishRefresh(domains: [.weight])

        guard case .loaded(let updated) = model.viewState else {
            return XCTFail("Expected loaded Journey state after weight refresh")
        }
        XCTAssertEqual(updated.baseline.currentWeightKg ?? 0, 82.5, accuracy: 0.01)
    }

    func testJourneyUpdatesProjectionAfterRemotePlanChange() async throws {
        let model = makeModel()
        await model.loadProgress()

        guard case .loaded(let initial) = model.viewState else {
            return XCTFail("Expected loaded Journey state")
        }
        XCTAssertEqual(initial.baseline.goalWeightKg, 62)

        _ = try harness.actionCenter.updatePlan(UserProfileUpdate(goalWeightKg: 58))

        try await publishRefresh(domains: [.plan])

        guard case .loaded(let updated) = model.viewState else {
            return XCTFail("Expected loaded Journey state after plan refresh")
        }
        XCTAssertEqual(updated.baseline.goalWeightKg, 58)
    }

    func testJourneyIgnoresRefreshEventForOtherUID() async throws {
        let model = makeModel()
        await model.loadProgress()

        guard case .loaded(let initial) = model.viewState else {
            return XCTFail("Expected loaded Journey state")
        }

        _ = try harness.weightLogService.logWeight(82.5, date: harness.today)

        try await publishRefresh(domains: [.weight], uid: otherUID)

        guard case .loaded(let unchanged) = model.viewState else {
            return XCTFail("Expected loaded Journey state after ignored event")
        }
        XCTAssertEqual(initial.baseline.currentWeightKg, unchanged.baseline.currentWeightKg)
    }

    func testJourneyDoesNotShowFalseEmptyDuringRefresh() async throws {
        let model = makeModel()
        await model.loadProgress()
        crossDeviceCoordinator.manualRefreshDelayNanoseconds = 100_000_000

        guard case .loaded = model.viewState else {
            return XCTFail("Expected loaded Journey state")
        }

        async let refreshTask = model.performManualCrossDeviceRefresh()
        try await Task.sleep(nanoseconds: 20_000_000)

        guard case .loaded = model.viewState else {
            return XCTFail("Expected loaded state during cross-device refresh")
        }

        await refreshTask
        XCTAssertEqual(crossDeviceCoordinator.manualRefreshCallCount, 1)
        XCTAssertFalse(model.isCrossDeviceRefreshing)
    }

    func testJourneyManualRefreshCallsCoordinator() async throws {
        let model = makeModel()
        await model.loadProgress()

        await model.performManualCrossDeviceRefresh()

        XCTAssertEqual(crossDeviceCoordinator.manualRefreshCallCount, 1)
        XCTAssertFalse(model.isCrossDeviceRefreshing)
    }

    // MARK: - Helpers

    private func makeModel() -> JourneyModel {
        let trainingStore = TrainingInsightsStore(
            integration: StubTrainingIntegrationProvider(refreshResult: .notConnected)
        )
        return JourneyModel(
            dailyLogReader: harness.dailyLogService,
            weightLogReader: harness.weightLogService,
            userProfileReader: harness.profileService,
            trainingInsightsStore: trainingStore,
            ownerUIDProvider: { self.sessionUID },
            accountDataRefreshEventBus: refreshEventBus,
            crossDeviceSyncCoordinator: crossDeviceCoordinator
        )
    }

    private func publishRefresh(
        domains: Set<AccountDataRefreshDomain>,
        uid: String? = nil
    ) async throws {
        try await CrossDeviceRefreshTestSupport.publishAndWait(
            bus: refreshEventBus,
            event: AccountDataRefreshEvent(
                uid: uid ?? sessionUID,
                domains: domains,
                reason: .realtimeSnapshot,
                createdAt: harness.today
            )
        )
    }
}
