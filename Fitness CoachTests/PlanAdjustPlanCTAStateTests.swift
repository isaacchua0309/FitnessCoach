//
//  PlanAdjustPlanCTAStateTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class PlanAdjustPlanCTAStateTests: XCTestCase {

    func testCTARenders() {
        let cta = PlanMissionControlFixtures.loseDashboard.adjustPlanCTA

        XCTAssertEqual(cta.heading, "Need to change direction?")
        XCTAssertEqual(
            cta.bodyCopy,
            FormaProductCopy.PlanMissionControl.adjustPlanCTABody
        )
        XCTAssertEqual(cta.buttonTitle, "Adjust Plan")
        XCTAssertTrue(cta.isEnabled)
        XCTAssertFalse(cta.accessibilitySummary.isEmpty)
    }

    func testNoDuplicatedSummaryRowsAppear() {
        let dashboard = PlanMissionControlFixtures.loseDashboard
        let cta = dashboard.adjustPlanCTA
        let combined = [
            cta.heading,
            cta.bodyCopy,
            cta.buttonTitle,
            cta.accessibilitySummary
        ].joined(separator: " ")

        XCTAssertFalse(combined.contains(dashboard.strategy.primaryGoal))
        XCTAssertFalse(combined.contains(dashboard.dailyTargets.caloriesLabel))
        XCTAssertFalse(combined.contains("Moderately active"))
        XCTAssertFalse(combined.contains("90 kg"))
        XCTAssertFalse(combined.contains("75 kg"))
    }

    @MainActor
    func testButtonOpensExistingAdjustPlanFlow() async throws {
        let analytics = CapturingPlanAnalyticsLogger()
        let container = try AppContainer(inMemory: true, planAnalyticsLogger: analytics)
        let model = container.makePlanModel()
        let formState = PlanFormState(profile: PlanMissionControlFixtures.loseProfile)
        let input = try formState.makeCalorieTargetInput()
        let result = try container.targetService.generateInitialTargets(from: input)
        var draftForm = formState
        draftForm.applyGeneratedTargets(result.targets)
        let draft = try draftForm.makeDraft(targets: result.targets)
        _ = try container.userProfileService.createProfile(draft)
        await model.loadProfile()

        model.showEditPlan()

        XCTAssertTrue(model.isShowingEditSheet)
        XCTAssertNotNil(model.editFormState)
        XCTAssertEqual(model.editPlanInitialStep, .goalAndTargetWeight)
        XCTAssertEqual(analytics.events.last?.properties.entryPoint, PlanAdjustPlanEntryPoint.dashboard.rawValue)
    }
}
