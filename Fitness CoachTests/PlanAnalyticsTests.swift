//
//  PlanAnalyticsTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class PlanAnalyticsContextBuilderTests: XCTestCase {

    func testPlanTypeBuckets() {
        XCTAssertEqual(
            PlanAnalyticsContextBuilder.planType(from: .aggressiveCut),
            "aggressive_cut"
        )
        XCTAssertEqual(
            PlanAnalyticsContextBuilder.planType(from: .moderateCut),
            "moderate_cut"
        )
        XCTAssertEqual(
            PlanAnalyticsContextBuilder.planType(from: .gentleCut),
            "moderate_cut"
        )
        XCTAssertEqual(
            PlanAnalyticsContextBuilder.planType(from: .maintenance),
            "maintenance"
        )
        XCTAssertEqual(
            PlanAnalyticsContextBuilder.planType(from: .leanGain),
            "lean_gain"
        )
        XCTAssertEqual(
            PlanAnalyticsContextBuilder.planType(from: .rebuild),
            "lean_gain"
        )
        XCTAssertEqual(
            PlanAnalyticsContextBuilder.planType(from: .needsReview),
            "needs_review"
        )
    }

    func testConfidenceBucketUsesEstimateBucketRawValue() {
        XCTAssertEqual(
            PlanAnalyticsContextBuilder.confidenceBucket(from: .low),
            "low"
        )
        XCTAssertEqual(
            PlanAnalyticsContextBuilder.confidenceBucket(from: .fair),
            "fair"
        )
        XCTAssertEqual(
            PlanAnalyticsContextBuilder.confidenceBucket(from: .good),
            "good"
        )
        XCTAssertEqual(
            PlanAnalyticsContextBuilder.confidenceBucket(from: .strong),
            "strong"
        )
    }

    func testSnapshotUsesBucketsNotRawProfileValues() {
        let dashboard = PlanMissionControlFixtures.loseDashboard
        let snapshot = PlanAnalyticsContextBuilder.snapshot(
            from: dashboard,
            healthConnected: true
        )

        XCTAssertEqual(snapshot.planType, "aggressive_cut")
        XCTAssertFalse(snapshot.confidenceBucket.isEmpty)
        XCTAssertTrue(snapshot.appleHealthConnected)
        XCTAssertFalse(snapshot.hasRecentWeighIn)
        XCTAssertFalse(snapshot.hasEnoughFoodLogs)

        let parameters = PlanAnalyticsProperties.from(snapshot: snapshot).asParameters()
        XCTAssertNil(parameters["calorieTarget"])
        XCTAssertNil(parameters["currentWeightKg"])
        XCTAssertNil(parameters["name"])
        XCTAssertNil(parameters["age"])
        XCTAssertNil(parameters["sex"])
    }

    func testSnapshotReflectsEngagementSignals() {
        let activeSnapshot = PlanAnalyticsContextBuilder.snapshot(
            from: PlanMissionControlFixtures.activeUserDashboard,
            healthConnected: true
        )
        XCTAssertTrue(activeSnapshot.hasRecentWeighIn)
        XCTAssertTrue(activeSnapshot.hasEnoughFoodLogs)
        XCTAssertTrue(activeSnapshot.appleHealthConnected)

        let sparseSnapshot = PlanAnalyticsContextBuilder.snapshot(
            from: PlanMissionControlFixtures.noLogsDashboard,
            healthConnected: false
        )
        XCTAssertFalse(sparseSnapshot.hasRecentWeighIn)
        XCTAssertFalse(sparseSnapshot.hasEnoughFoodLogs)
        XCTAssertFalse(sparseSnapshot.appleHealthConnected)
    }

    func testAsParametersUseSnakeCaseKeys() {
        let snapshot = PlanAnalyticsSnapshot(
            planType: "moderate_cut",
            confidenceBucket: "good",
            appleHealthConnected: true,
            hasRecentWeighIn: false,
            hasEnoughFoodLogs: true
        )

        let parameters = PlanAnalyticsProperties.from(snapshot: snapshot).asParameters()
        XCTAssertEqual(parameters["plan_type"], "moderate_cut")
        XCTAssertEqual(parameters["confidence_bucket"], "good")
        XCTAssertEqual(parameters["apple_health_connected"], "true")
        XCTAssertEqual(parameters["has_recent_weigh_in"], "false")
        XCTAssertEqual(parameters["has_enough_food_logs"], "true")
    }
}

@MainActor
final class PlanAnalyticsEventTests: XCTestCase {

    private var analytics: CapturingPlanAnalyticsLogger!
    private var container: AppContainer!
    private var model: PlanModel!

    override func setUp() async throws {
        analytics = CapturingPlanAnalyticsLogger()
        container = try AppContainer(inMemory: true, planAnalyticsLogger: analytics)
        model = container.makePlanModel()
        try await seedProfile()
        await model.loadProfile()
    }

    func testLogPlanViewedIncludesBucketProperties() {
        model.logPlanViewed(healthConnected: false)

        XCTAssertEqual(analytics.events.count, 1)
        XCTAssertEqual(analytics.events[0].event, .viewed)
        XCTAssertEqual(analytics.events[0].properties.planType, "aggressive_cut")
        XCTAssertFalse(analytics.events[0].properties.confidenceBucket?.isEmpty ?? true)
        XCTAssertEqual(analytics.events[0].properties.appleHealthConnected, false)
        XCTAssertEqual(analytics.events[0].properties.hasRecentWeighIn, false)
        XCTAssertEqual(analytics.events[0].properties.hasEnoughFoodLogs, false)
    }

    func testSectionImpressionsDedupeWithinSession() {
        model.logSectionImpression(.strategy, healthConnected: true)
        model.logSectionImpression(.strategy, healthConnected: true)
        model.logSectionImpression(.status, healthConnected: true)

        XCTAssertEqual(
            analytics.events.map(\.event),
            [.strategyViewed, .statusViewed]
        )
    }

    func testSectionImpressionsResetAfterRefresh() async {
        model.logSectionImpression(.strategy, healthConnected: true)
        await model.refresh()
        model.logSectionImpression(.strategy, healthConnected: true)

        XCTAssertEqual(analytics.events.filter { $0.event == .strategyViewed }.count, 2)
    }

    func testAdjustStartedIncludesEntryPointAndBuckets() {
        model.showEditPlan()

        XCTAssertEqual(analytics.events.last?.event, .adjustStarted)
        XCTAssertEqual(analytics.events.last?.properties.entryPoint, PlanAdjustPlanEntryPoint.dashboard)
        XCTAssertEqual(analytics.events.last?.properties.planType, "aggressive_cut")
        XCTAssertNotNil(analytics.events.last?.properties.confidenceBucket)
    }

    func testLogPlanAdjustCTATapped() {
        model.logPlanAdjustCTATapped(healthConnected: true)

        XCTAssertEqual(analytics.events.last?.event, .adjustCTATapped)
        XCTAssertEqual(analytics.events.last?.properties.planType, "aggressive_cut")
        XCTAssertEqual(analytics.events.last?.properties.appleHealthConnected, true)
    }

    func testLogPlanActivityUpdateTapped() {
        model.logPlanActivityUpdateTapped(healthConnected: false)

        XCTAssertEqual(analytics.events.last?.event, .activityUpdateTapped)
        XCTAssertEqual(analytics.events.last?.properties.planType, "aggressive_cut")
        XCTAssertEqual(analytics.events.last?.properties.appleHealthConnected, false)
    }

    func testLogPlanTodayTapped() {
        model.logPlanTodayTapped(healthConnected: true)

        XCTAssertEqual(analytics.events.map(\.event), [.todayTapped])
        XCTAssertEqual(analytics.events[0].properties.planType, "aggressive_cut")
    }

    func testLogPlanHealthConnectTappedIncludesEntryPoint() {
        model.logPlanHealthConnectTapped(
            entryPoint: .planConfidence,
            healthConnected: false
        )

        XCTAssertEqual(analytics.events.last?.event, .healthConnectTapped)
        XCTAssertEqual(analytics.events.last?.properties.entryPoint, "plan_confidence")
    }

    func testLogPlanCalculationTapped() {
        model.logPlanCalculationTapped(healthConnected: true)

        XCTAssertEqual(analytics.events.last?.event, .calculationTapped)
        XCTAssertEqual(analytics.events.last?.properties.planType, "aggressive_cut")
    }

    func testSavePlanFromWizardLogsEditSaved() async throws {
        model.showEditPlan()
        guard let formState = model.editFormState else {
            return XCTFail("Expected edit form state")
        }

        try await model.savePlanFromWizard(formState)

        XCTAssertTrue(analytics.events.contains { $0.event == .editSaved })
        XCTAssertNil(analytics.events.first { $0.event == .editSaved }?.properties.entryPoint)
    }

    func testApplyGeneratedTargetsLogsTargetsRegenerated() async {
        model.showEditPlan()
        guard let formState = model.editFormState else {
            return XCTFail("Expected edit form state")
        }
        await model.previewRegeneratedTargets(from: formState)
        await model.applyGeneratedTargets()

        XCTAssertTrue(analytics.events.contains { $0.event == .targetsRegenerated })
    }

    func testAllEventRawValuesMatchContract() {
        XCTAssertEqual(PlanAnalyticsEvent.viewed.rawValue, "plan_viewed")
        XCTAssertEqual(PlanAnalyticsEvent.strategyViewed.rawValue, "plan_strategy_viewed")
        XCTAssertEqual(PlanAnalyticsEvent.statusViewed.rawValue, "plan_status_viewed")
        XCTAssertEqual(PlanAnalyticsEvent.confidenceViewed.rawValue, "plan_confidence_viewed")
        XCTAssertEqual(PlanAnalyticsEvent.adjustCTATapped.rawValue, "plan_adjust_cta_tapped")
        XCTAssertEqual(PlanAnalyticsEvent.calculationTapped.rawValue, "plan_calculation_tapped")
        XCTAssertEqual(PlanAnalyticsEvent.activityUpdateTapped.rawValue, "plan_activity_update_tapped")
        XCTAssertEqual(PlanAnalyticsEvent.adjustStarted.rawValue, "plan_adjust_started")
        XCTAssertEqual(PlanAnalyticsEvent.editSaved.rawValue, "plan_edit_saved")
        XCTAssertEqual(PlanAnalyticsEvent.targetsRegenerated.rawValue, "plan_targets_regenerated")
        XCTAssertEqual(PlanAnalyticsEvent.healthConnectTapped.rawValue, "plan_health_connect_tapped")
        XCTAssertEqual(PlanAnalyticsEvent.todayTapped.rawValue, "plan_today_tapped")
    }

    private func seedProfile() async throws {
        let formState = PlanFormState(profile: PlanMissionControlFixtures.loseProfile)
        let input = try formState.makeCalorieTargetInput()
        let result = try container.targetService.generateInitialTargets(from: input)
        var draftForm = formState
        draftForm.applyGeneratedTargets(result.targets)
        let draft = try draftForm.makeDraft(targets: result.targets)
        _ = try container.userProfileService.createProfile(draft)
    }
}
