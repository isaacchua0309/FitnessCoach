//
//  PlanAnalyticsTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class PlanAnalyticsContextBuilderTests: XCTestCase {

    func testCalorieTargetBuckets() {
        XCTAssertEqual(PlanAnalyticsContextBuilder.calorieTargetBucket(1700), "under_1800")
        XCTAssertEqual(PlanAnalyticsContextBuilder.calorieTargetBucket(2000), "1800_2199")
        XCTAssertEqual(PlanAnalyticsContextBuilder.calorieTargetBucket(2400), "2200_2599")
        XCTAssertEqual(PlanAnalyticsContextBuilder.calorieTargetBucket(2800), "2600_plus")
    }

    func testGoalTypeBuckets() {
        XCTAssertEqual(
            PlanAnalyticsContextBuilder.goalType(for: PlanMissionControlFixtures.loseProfile),
            "lose"
        )
        XCTAssertEqual(
            PlanAnalyticsContextBuilder.goalType(for: PlanMissionControlFixtures.gainProfile),
            "gain"
        )
        XCTAssertEqual(
            PlanAnalyticsContextBuilder.goalType(for: PlanMissionControlFixtures.maintainProfile),
            "maintain"
        )
    }

    func testSnapshotUsesBucketsNotRawProfileValues() {
        let dashboard = PlanStateBuilder.dashboardState(profile: PlanMissionControlFixtures.loseProfile)
        let snapshot = PlanAnalyticsContextBuilder.snapshot(
            from: dashboard,
            healthConnected: true
        )

        XCTAssertEqual(snapshot.goalType, "lose")
        XCTAssertEqual(snapshot.calorieTargetBucket, "2200_2599")
        XCTAssertEqual(snapshot.activityLevel, ActivityLevel.moderatelyActive.rawValue)
        XCTAssertTrue(snapshot.healthConnected)
        XCTAssertFalse(snapshot.progressBucket.isEmpty)

        let parameters = PlanAnalyticsProperties.from(snapshot: snapshot).asParameters()
        XCTAssertNil(parameters["calorieTarget"])
        XCTAssertNil(parameters["currentWeightKg"])
        XCTAssertNil(parameters["name"])
    }

    func testProgressBucketFromMissionState() {
        var mission = PlanMissionControlFixtures.loseDashboard.mission
        mission.progressPercent = nil
        mission.showsProgressBar = false
        XCTAssertEqual(
            PlanAnalyticsContextBuilder.progressBucket(from: mission),
            PlanAnalyticsGoalProgressBucket.unknown.rawValue
        )

        mission.showsProgressBar = true
        XCTAssertEqual(
            PlanAnalyticsContextBuilder.progressBucket(from: mission),
            PlanAnalyticsGoalProgressBucket.none.rawValue
        )

        mission.progressPercent = 0.9
        XCTAssertEqual(
            PlanAnalyticsContextBuilder.progressBucket(from: mission),
            PlanAnalyticsGoalProgressBucket.onTrack.rawValue
        )
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
        guard case .loaded(let state) = model.viewState else {
            return XCTFail("Expected loaded state")
        }
        let expectedBucket = PlanAnalyticsContextBuilder.calorieTargetBucket(
            state.profile.targets.calorieTarget
        )

        model.logPlanViewed(healthConnected: false)

        XCTAssertEqual(analytics.events.count, 1)
        XCTAssertEqual(analytics.events[0].event, .viewed)
        XCTAssertEqual(analytics.events[0].properties.goalType, "lose")
        XCTAssertEqual(analytics.events[0].properties.calorieTargetBucket, expectedBucket)
        XCTAssertEqual(analytics.events[0].properties.healthConnected, false)
        XCTAssertEqual(analytics.events[0].properties.activityLevel, ActivityLevel.moderatelyActive.rawValue)
    }

    func testSectionImpressionsDedupeWithinSession() {
        model.logSectionImpression(.goalCard, healthConnected: true)
        model.logSectionImpression(.goalCard, healthConnected: true)
        model.logSectionImpression(.todayMission, healthConnected: true)

        XCTAssertEqual(analytics.events.map(\.event), [.goalCardViewed, .todayMissionViewed])
    }

    func testSectionImpressionsResetAfterRefresh() async {
        model.logSectionImpression(.goalCard, healthConnected: true)
        await model.refresh()
        model.logSectionImpression(.goalCard, healthConnected: true)

        XCTAssertEqual(analytics.events.filter { $0.event == .goalCardViewed }.count, 2)
    }

    func testAdjustStartedIncludesEntryPointAndBuckets() {
        model.showEditPlan()

        XCTAssertEqual(analytics.events.last?.event, .adjustStarted)
        XCTAssertEqual(analytics.events.last?.properties.entryPoint, PlanAdjustPlanEntryPoint.dashboard)
        XCTAssertEqual(analytics.events.last?.properties.goalType, "lose")
        XCTAssertNotNil(analytics.events.last?.properties.calorieTargetBucket)
    }

    func testLogPlanTodayAndJourneyTapped() {
        model.logPlanTodayTapped(healthConnected: true)
        model.logPlanJourneyTapped(healthConnected: true)

        XCTAssertEqual(analytics.events.map(\.event), [.todayTapped, .journeyTapped])
        XCTAssertEqual(analytics.events[0].properties.goalType, "lose")
    }

    func testLogPlanHealthConnectTappedIncludesEntryPoint() {
        model.logPlanHealthConnectTapped(
            entryPoint: .activityAssumptions,
            healthConnected: false
        )

        XCTAssertEqual(analytics.events.last?.event, .healthConnectTapped)
        XCTAssertEqual(analytics.events.last?.properties.entryPoint, "activity_assumptions")
    }

    func testLogPlanCalculationDetailsOpened() {
        model.logPlanCalculationDetailsOpened(healthConnected: true)

        XCTAssertEqual(analytics.events.last?.event, .calculationDetailsOpened)
        XCTAssertEqual(analytics.events.last?.properties.goalType, "lose")
    }

    func testSavePlanFromWizardLogsEditSaved() async throws {
        model.showEditPlan()
        guard let formState = model.editFormState else {
            return XCTFail("Expected edit form state")
        }

        await model.savePlanFromWizard(formState)

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
        XCTAssertEqual(PlanAnalyticsEvent.goalCardViewed.rawValue, "plan_goal_card_viewed")
        XCTAssertEqual(PlanAnalyticsEvent.todayMissionViewed.rawValue, "plan_today_mission_viewed")
        XCTAssertEqual(PlanAnalyticsEvent.weekSectionViewed.rawValue, "plan_week_section_viewed")
        XCTAssertEqual(PlanAnalyticsEvent.rationaleOpened.rawValue, "plan_rationale_opened")
        XCTAssertEqual(PlanAnalyticsEvent.calculationDetailsOpened.rawValue, "plan_calculation_details_opened")
        XCTAssertEqual(PlanAnalyticsEvent.activityAssumptionsViewed.rawValue, "plan_activity_assumptions_viewed")
        XCTAssertEqual(PlanAnalyticsEvent.adjustStarted.rawValue, "plan_adjust_started")
        XCTAssertEqual(PlanAnalyticsEvent.editSaved.rawValue, "plan_edit_saved")
        XCTAssertEqual(PlanAnalyticsEvent.targetsRegenerated.rawValue, "plan_targets_regenerated")
        XCTAssertEqual(PlanAnalyticsEvent.healthConnectTapped.rawValue, "plan_health_connect_tapped")
        XCTAssertEqual(PlanAnalyticsEvent.todayTapped.rawValue, "plan_today_tapped")
        XCTAssertEqual(PlanAnalyticsEvent.journeyTapped.rawValue, "plan_journey_tapped")
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
