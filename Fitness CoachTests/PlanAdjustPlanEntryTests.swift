//
//  PlanAdjustPlanEntryTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class PlanAdjustPlanEntryTests: XCTestCase {

    private var analytics: CapturingPlanAnalyticsLogger!
    private var container: AppContainer!
    private var model: ProfileModel!

    override func setUp() async throws {
        analytics = CapturingPlanAnalyticsLogger()
        container = try AppContainer(inMemory: true, planAnalyticsLogger: analytics)
        model = container.makeProfileModel()
        try await seedProfile()
        await model.loadProfile()
    }

    // MARK: - Summary rendering

    func testLosePlanSummaryRowsMatchCurrentPlan() {
        let adjustment = PlanMissionControlFixtures.loseDashboard.adjustment

        XCTAssertEqual(adjustment.sectionTitle, "Adjust Plan")
        XCTAssertEqual(adjustment.currentHeading, "Current:")
        XCTAssertEqual(adjustment.summaryRows.map(\.id), ["goal", "targetWeight", "activity", "dailyTarget"])

        let rows = Dictionary(uniqueKeysWithValues: adjustment.summaryRows.map { ($0.id, $0.value) })
        XCTAssertEqual(rows["goal"], "Lose weight")
        XCTAssertEqual(rows["targetWeight"], "75 kg")
        XCTAssertEqual(rows["activity"], "Moderately active")
        XCTAssertTrue(rows["dailyTarget"]?.contains("kcal") == true)
    }

    func testGainPlanSummaryUsesGainGoalCopy() {
        let adjustment = PlanMissionControlFixtures.gainDashboard.adjustment
        let goal = adjustment.summaryRows.first { $0.id == "goal" }

        XCTAssertEqual(goal?.value, "Gain weight")
    }

    func testAccessibilitySummaryIncludesSummaryValues() {
        let adjustment = PlanMissionControlFixtures.loseDashboard.adjustment

        XCTAssertTrue(adjustment.accessibilitySummary.contains("Adjust Plan"))
        XCTAssertTrue(adjustment.accessibilitySummary.contains("Lose weight"))
        XCTAssertTrue(adjustment.accessibilitySummary.contains("75 kg"))
    }

    // MARK: - Routing & analytics

    func testShowEditPlanOpensWizardAndLogsAnalytics() {
        model.showEditPlan()

        XCTAssertTrue(model.isShowingEditSheet)
        XCTAssertNotNil(model.editFormState)
        XCTAssertEqual(model.editPlanInitialStep, .goalAndTargetWeight)
        XCTAssertEqual(analytics.events.count, 1)
        XCTAssertEqual(analytics.events[0].event, .adjustStarted)
        XCTAssertEqual(analytics.events[0].properties.entryPoint, PlanAdjustPlanEntryPoint.dashboard)
        XCTAssertEqual(analytics.events[0].properties.initialStep, 0)
    }

    func testShowEditPlanActivityRoutesToActivityStep() {
        model.showEditPlanActivity()

        XCTAssertTrue(model.isShowingEditSheet)
        XCTAssertEqual(model.editPlanInitialStep, .activityLevel)
        XCTAssertEqual(analytics.events.last?.properties.entryPoint, PlanAdjustPlanEntryPoint.activityAssumptions)
        guard let formState = model.editFormState else {
            return XCTFail("Expected edit form state")
        }
        XCTAssertEqual(
            analytics.events.last?.properties.initialStep,
            PlanEditWizardFlow.index(of: .activityLevel, formState: formState)
        )
    }

    func testShowEditPlanDoesNothingWhenNotLoaded() async throws {
        let localAnalytics = CapturingPlanAnalyticsLogger()
        let freshContainer = try AppContainer(inMemory: true, planAnalyticsLogger: localAnalytics)
        let emptyModel = freshContainer.makeProfileModel()

        emptyModel.showEditPlan()

        XCTAssertFalse(emptyModel.isShowingEditSheet)
        XCTAssertTrue(localAnalytics.events.isEmpty)
    }

    // MARK: - Fixtures

    private func seedProfile() async throws {
        let formState = ProfileFormState(profile: PlanMissionControlFixtures.loseProfile)
        let input = try formState.makeCalorieTargetInput()
        let result = try container.targetService.generateInitialTargets(from: input)
        var draftForm = formState
        draftForm.applyGeneratedTargets(result.targets)
        let draft = try draftForm.makeDraft(targets: result.targets)
        _ = try container.userProfileService.createProfile(draft)
    }
}
