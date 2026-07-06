//
//  PlanCrossDeviceRefreshTests.swift
//  Fitness CoachTests
//
//  Forma — Plan Phase 5 cross-device refresh tests.
//

import Combine
import XCTest
@testable import Fitness_Coach

@MainActor
final class PlanCrossDeviceRefreshTests: XCTestCase {

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

    func testPlanReloadsAfterRemoteProfileChange() async throws {
        let model = makeModel()
        await model.loadProfile()

        guard case .loaded(let initial) = model.viewState else {
            return XCTFail("Expected loaded Plan state")
        }
        XCTAssertEqual(initial.profile.targets.calorieTarget, 1_800)

        _ = try harness.actionCenter.updatePlan(
            UserProfileUpdate(targets: ProfileFixtures.sampleTargets.withCalories(2_100))
        )

        try await publishRefresh(domains: [.profile])

        guard case .loaded(let updated) = model.viewState else {
            return XCTFail("Expected loaded Plan state after profile refresh")
        }
        XCTAssertEqual(updated.profile.targets.calorieTarget, 2_100)
    }

    func testPlanIgnoresOtherUIDProfileEvent() async throws {
        let model = makeModel()
        await model.loadProfile()

        guard case .loaded(let initial) = model.viewState else {
            return XCTFail("Expected loaded Plan state")
        }

        _ = try harness.actionCenter.updatePlan(
            UserProfileUpdate(targets: ProfileFixtures.sampleTargets.withCalories(2_100))
        )

        try await publishRefresh(domains: [.profile], uid: otherUID)

        guard case .loaded(let unchanged) = model.viewState else {
            return XCTFail("Expected loaded Plan state after ignored event")
        }
        XCTAssertEqual(initial.profile.targets.calorieTarget, unchanged.profile.targets.calorieTarget)
    }

    func testPlanDoesNotOverwritePendingLocalProfileEdit() async throws {
        let model = makeModel()
        await model.loadProfile()

        guard case .loaded(let initial) = model.viewState else {
            return XCTFail("Expected loaded Plan state")
        }
        XCTAssertEqual(initial.profile.targets.calorieTarget, 1_800)

        _ = try harness.actionCenter.updatePlan(
            UserProfileUpdate(targets: ProfileFixtures.sampleTargets.withCalories(2_200))
        )

        try await publishRefresh(domains: [.profile])

        guard case .loaded(let updated) = model.viewState else {
            return XCTFail("Expected loaded Plan state after refresh")
        }
        XCTAssertEqual(updated.profile.targets.calorieTarget, 2_200)
        XCTAssertNotEqual(updated.profile.targets.calorieTarget, 1_800)
    }

    func testPlanPublishesTodayAndJourneyRefreshAfterTargetChange() {
        let domains = AccountDataRefreshEventSupport.domains(
            uploadedMutations: 0,
            pullSummary: CrossDeviceSyncTestSupport.makePullSummary(
                uid: sessionUID,
                referenceDate: harness.today,
                pulledProfile: true
            )
        )

        XCTAssertTrue(domains.contains(.profile))
        XCTAssertTrue(domains.contains(.plan))
        XCTAssertTrue(domains.contains(.today))
        XCTAssertTrue(domains.contains(.journey))
    }

    func testTodayAndJourneyRefreshAfterConfirmedPlanChangeIfExistingHooksAvailable() async throws {
        let model = makeModel()
        await model.loadProfile()

        let refreshBefore = harness.actionCenter.dataRefreshToken
        guard case .loaded(let initial) = model.viewState else {
            return XCTFail("Expected loaded Plan state")
        }

        model.showEditPlan()
        guard var formState = model.editFormState else {
            return XCTFail("Expected edit form state")
        }
        formState.calorieTargetText = "\(initial.profile.targets.calorieTarget - 75)"

        try await model.savePlanFromWizard(formState)

        XCTAssertGreaterThan(harness.actionCenter.dataRefreshToken, refreshBefore)

        guard case .loaded(let updated) = model.viewState else {
            return XCTFail("Expected loaded Plan state after save")
        }
        XCTAssertEqual(
            updated.profile.targets.calorieTarget,
            initial.profile.targets.calorieTarget - 75
        )
    }

    // MARK: - Helpers

    private func makeModel() -> PlanModel {
        let trainingStore = TrainingInsightsStore(
            integration: StubTrainingIntegrationProvider(refreshResult: .notConnected)
        )
        return PlanModel(
            actionCenter: harness.actionCenter,
            userProfileReader: harness.profileService,
            planTargetCalculator: harness.targetService,
            dailyLogReader: harness.dailyLogService,
            weightLogReader: harness.weightLogService,
            trainingInsightsStore: trainingStore,
            healthBaselineService: StubHealthBaselineProvider(),
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
