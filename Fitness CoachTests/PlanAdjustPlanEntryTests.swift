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
    private var model: PlanModel!

    override func setUp() async throws {
        analytics = CapturingPlanAnalyticsLogger()
        container = try AppContainer(inMemory: true, planAnalyticsLogger: analytics)
        model = container.makePlanModel()
        try await seedProfile()
        await model.loadProfile()
    }

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
        XCTAssertEqual(analytics.events.last?.properties.entryPoint, PlanAdjustPlanEntryPoint.planAssumptions)
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
        let emptyModel = freshContainer.makePlanModel()

        emptyModel.showEditPlan()

        XCTAssertFalse(emptyModel.isShowingEditSheet)
        XCTAssertTrue(localAnalytics.events.isEmpty)
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
