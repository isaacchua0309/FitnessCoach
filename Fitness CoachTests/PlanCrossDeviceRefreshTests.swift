//
//  PlanCrossDeviceRefreshTests.swift
//  Fitness CoachTests
//
//  Forma — Plan Phase 5 cross-device refresh tests.
//

import Combine
import XCTest
@testable import Fitness_Coach

final class PlanCrossDeviceRefreshPolicyTests: XCTestCase {

    private let ownerUID = "user-a"
    private let referenceDate = ProfileTestFixtures.referenceDate

    func testShouldReloadForPlanRelevantDomains() {
        for domain in PlanCrossDeviceRefreshPolicy.relevantDomains {
            let event = AccountDataRefreshEvent(
                uid: ownerUID,
                domains: [domain],
                reason: .realtimeSnapshot,
                createdAt: referenceDate
            )
            XCTAssertTrue(PlanCrossDeviceRefreshPolicy.shouldReload(for: event))
        }
    }

    func testShouldIgnoreCoachOnlyDomain() {
        let event = AccountDataRefreshEvent(
            uid: ownerUID,
            domains: [.coachContext],
            reason: .realtimeSnapshot,
            createdAt: referenceDate
        )
        XCTAssertFalse(PlanCrossDeviceRefreshPolicy.shouldReload(for: event))
    }

    func testMatchesCurrentUIDRejectsOtherAccounts() {
        let event = AccountDataRefreshEvent(
            uid: "other-user",
            domains: [.plan],
            reason: .appForeground,
            createdAt: referenceDate
        )
        XCTAssertFalse(
            PlanCrossDeviceRefreshPolicy.matchesCurrentUID(
                event: event,
                ownerUIDProvider: { self.ownerUID }
            )
        )
    }
}

@MainActor
final class PlanCrossDeviceRefreshModelTests: XCTestCase {

    private var harness: FitnessActionCenterTestSupport.Harness!
    private var refreshEventBus: AccountDataRefreshEventBus!
    private var crossDeviceCoordinator: TrackingPlanCrossDeviceSyncCoordinator!
    private var sessionUID: String!

    override func setUp() async throws {
        harness = try FitnessActionCenterTestSupport.makeHarness()
        refreshEventBus = AccountDataRefreshEventBus()
        crossDeviceCoordinator = TrackingPlanCrossDeviceSyncCoordinator()
        sessionUID = "test-user-1"
        _ = try harness.seedProfile(ownerUID: sessionUID)
    }

    override func tearDown() {
        harness = nil
        refreshEventBus = nil
        crossDeviceCoordinator = nil
        sessionUID = nil
        super.tearDown()
    }

    func testModelIgnoresRefreshEventsForOtherUID() async throws {
        let model = makeModel()
        await model.loadProfile()

        guard case .loaded(let initial) = model.viewState else {
            return XCTFail("Expected loaded plan state")
        }

        _ = try harness.actionCenter.updatePlan(
            UserProfileUpdate(targets: ProfileTestFixtures.sampleTargets.withCalories(2_100))
        )
        refreshEventBus.publish(
            AccountDataRefreshEvent(
                uid: "other-user",
                domains: [.plan],
                reason: .realtimeSnapshot,
                createdAt: harness.today
            )
        )
        refreshEventBus.flushImmediately()
        try await Task.sleep(nanoseconds: 300_000_000)

        guard case .loaded(let unchanged) = model.viewState else {
            return XCTFail("Expected loaded plan state after ignored event")
        }
        XCTAssertEqual(initial.profile.targets.calorieTarget, unchanged.profile.targets.calorieTarget)
    }

    func testModelReloadsAfterRelevantCrossDeviceEvent() async throws {
        let model = makeModel()
        await model.loadProfile()

        guard case .loaded(let initial) = model.viewState else {
            return XCTFail("Expected loaded plan state")
        }
        XCTAssertNotEqual(initial.profile.targets.calorieTarget, 2_100)

        _ = try harness.actionCenter.updatePlan(
            UserProfileUpdate(targets: ProfileTestFixtures.sampleTargets.withCalories(2_100))
        )
        refreshEventBus.publish(
            AccountDataRefreshEvent(
                uid: sessionUID,
                domains: [.profile],
                reason: .realtimeSnapshot,
                createdAt: harness.today
            )
        )
        refreshEventBus.flushImmediately()
        try await Task.sleep(nanoseconds: 300_000_000)

        guard case .loaded(let updated) = model.viewState else {
            return XCTFail("Expected loaded plan state after refresh")
        }
        XCTAssertEqual(updated.profile.targets.calorieTarget, 2_100)
    }

    func testManualCrossDeviceRefreshKeepsLoadedStateVisible() async throws {
        let model = makeModel()
        await model.loadProfile()
        crossDeviceCoordinator.manualRefreshDelayNanoseconds = 100_000_000

        guard case .loaded = model.viewState else {
            return XCTFail("Expected loaded plan state")
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

    func testRefreshFailurePreservesLoadedDashboard() async throws {
        let failingReader = FailablePlanProfileReader(underlying: harness.profileService)
        let model = makeModel(userProfileReader: failingReader)
        await model.loadProfile()

        guard case .loaded = model.viewState else {
            return XCTFail("Expected loaded plan state")
        }

        failingReader.failOnNextRead()
        await model.refresh()

        guard case .loaded = model.viewState else {
            return XCTFail("Expected loaded state to be preserved after refresh failure")
        }
    }

    private func makeModel(
        userProfileReader: (any UserProfileReading)? = nil
    ) -> PlanModel {
        let trainingStore = TrainingInsightsStore(
            integration: StubTrainingIntegrationProvider(refreshResult: .notConnected)
        )
        return PlanModel(
            actionCenter: harness.actionCenter,
            userProfileReader: userProfileReader ?? harness.profileService,
            planTargetCalculator: harness.targetService,
            dailyLogReader: harness.dailyLogService,
            weightLogReader: harness.weightLogService,
            trainingInsightsStore: trainingStore,
            healthBaselineService: StubHealthBaselineProvider(),
            healthIntelligenceLoadEnabled: { false },
            ownerUIDProvider: { self.sessionUID },
            accountDataRefreshEventBus: refreshEventBus,
            crossDeviceSyncCoordinator: crossDeviceCoordinator
        )
    }
}

@MainActor
private final class TrackingPlanCrossDeviceSyncCoordinator: CrossDeviceSyncCoordinating {

    var manualRefreshCallCount = 0
    var manualRefreshDelayNanoseconds: UInt64 = 0

    func refreshNow(
        uid: String,
        mode: CrossDeviceSyncMode,
        reason: CrossDeviceSyncReason
    ) async -> CrossDeviceSyncSummary {
        emptySummary(uid: uid, mode: mode, reason: reason)
    }

    func foregroundRefreshIfNeeded(uid: String) async -> CrossDeviceSyncSummary? { nil }

    func manualRefresh(uid: String) async -> CrossDeviceSyncSummary {
        manualRefreshCallCount += 1
        if manualRefreshDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: manualRefreshDelayNanoseconds)
        }
        return emptySummary(uid: uid, mode: .manualRefresh, reason: .manualPullToRefresh)
    }

    func handleRealtimeHint(uid: String) async -> CrossDeviceSyncSummary? { nil }

    private func emptySummary(
        uid: String,
        mode: CrossDeviceSyncMode,
        reason: CrossDeviceSyncReason
    ) -> CrossDeviceSyncSummary {
        CrossDeviceSyncSummary(
            uid: uid,
            mode: mode,
            reason: reason,
            status: .completed,
            startedAt: Date(),
            endedAt: Date(),
            uploadedMutations: 0,
            pulledDailyLogs: 0,
            pulledFoodEntries: 0,
            pulledWaterEntries: 0,
            pulledWeightEntries: 0,
            pulledDailyReviews: 0,
            pulledProfile: false,
            inserted: 0,
            updated: 0,
            deleted: 0,
            skippedLocalNewer: 0,
            conflicts: 0,
            failed: 0,
            didRefreshUI: false,
            userFacingMessage: nil
        )
    }
}

@MainActor
private final class FailablePlanProfileReader: UserProfileReading {
    private let underlying: UserProfileService
    private var shouldFail = false

    init(underlying: UserProfileService) {
        self.underlying = underlying
    }

    func failOnNextRead() {
        shouldFail = true
    }

    func getCurrentProfile() throws -> UserProfile? {
        if shouldFail { throw ServiceError.persistenceFailed("simulated failure") }
        return try underlying.getCurrentProfile()
    }

    func getCurrentProfileOwnerUID() throws -> String? {
        if shouldFail { throw ServiceError.persistenceFailed("simulated failure") }
        return try underlying.getCurrentProfileOwnerUID()
    }

    func currentProfileOwnership(for sessionUID: String) throws -> ProfileOwnershipStatus {
        if shouldFail { throw ServiceError.persistenceFailed("simulated failure") }
        return try underlying.currentProfileOwnership(for: sessionUID)
    }
}

private extension UserTargets {
    func withCalories(_ calories: Int) -> UserTargets {
        UserTargets(
            calorieTarget: calories,
            proteinTarget: proteinTarget,
            carbTarget: carbTarget,
            fatTarget: fatTarget,
            waterTargetMl: waterTargetMl,
            expectedWeeklyWeightLossKg: expectedWeeklyWeightLossKg,
            aggressiveness: aggressiveness
        )
    }
}
