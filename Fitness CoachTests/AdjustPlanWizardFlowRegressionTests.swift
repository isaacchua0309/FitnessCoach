//
//  AdjustPlanWizardFlowRegressionTests.swift
//  Fitness CoachTests
//
//  Forma — Flow regression coverage backing Adjust Plan manual QA steps 13–16.
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class AdjustPlanWizardFlowRegressionTests: XCTestCase {

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

    // MARK: - Steps 13–14: Cancel and reopen

    func testCancelDismissesAdjustPlanSheet() {
        model.showEditPlan()
        XCTAssertTrue(model.isShowingEditSheet)

        model.dismissEditPlan()

        XCTAssertFalse(model.isShowingEditSheet)
        XCTAssertNil(model.editWeeklyReviewContext)
    }

    func testReopenAfterCancelProvidesFreshEditFormState() {
        model.showEditPlan()
        guard var firstForm = model.editFormState else {
            return XCTFail("Expected edit form state")
        }
        firstForm.goalWeightKgText = "60"
        model.editFormState = firstForm

        model.dismissEditPlan()
        model.showEditPlan()

        guard let reopenedForm = model.editFormState else {
            return XCTFail("Expected edit form state after reopen")
        }
        XCTAssertNotEqual(reopenedForm.goalWeightKgText, "60")
        XCTAssertEqual(
            reopenedForm.goalWeightKgText,
            PlanFormState(profile: PlanMissionControlFixtures.loseProfile).goalWeightKgText
        )
    }

    // MARK: - Steps 2–4, 15–16: Goal selection and persistence through flow

    func testGoalSelectionUpdatesProjectionAndPathPreview() {
        var formState = AdjustPlanRegressionFixtures.formState(currentWeightKg: 90, goalWeightKg: 85)

        let loseProjection = PlanProjectionBuilder.build(formState: formState, goalType: .loseFat)
        XCTAssertEqual(loseProjection.goalLabel, FormaProductCopy.PlanEditGoal.loseFatTitle)

        formState.goalWeightKgText = "90"
        let maintainProjection = PlanProjectionBuilder.build(formState: formState, goalType: .maintain)
        XCTAssertEqual(maintainProjection.goalLabel, FormaProductCopy.PlanEditGoal.maintainTitle)

        formState.goalWeightKgText = "93"
        let gainProjection = PlanProjectionBuilder.build(formState: formState, goalType: .gainMuscle)
        XCTAssertEqual(gainProjection.goalLabel, FormaProductCopy.PlanEditGoal.gainMuscleTitle)

        let gainPath = AdjustPlanRegressionFixtures.pathState(goalType: .gainMuscle, formState: formState)
        XCTAssertEqual(gainPath.targetWeight, "93 kg")
    }

    func testGoalWeightChangesMarkReviewAsChangedForWizardPersistence() {
        let baseline = PlanMissionControlFixtures.loseProfile
        var formState = PlanFormState(profile: baseline)
        formState.goalWeightKgText = "85"

        let review = PlanEditReviewBuilder.build(baseline: baseline, formState: formState)
        XCTAssertTrue(review.hasChanges)
        XCTAssertTrue(review.changes.contains { $0.id == "goalWeight" })
    }

    func testGoalStepAdvancementEligibleForNonCutGoalsWithoutPace() {
        let formState = PlanFormState(profile: PlanMissionControlFixtures.loseProfile)

        XCTAssertTrue(
            PlanEditWizardStepGate.canAdvance(
                from: .goalAndTargetWeight,
                formState: formState,
                goalType: .maintain,
                goalWeightValidationMessage: nil,
                pacePreview: .empty
            )
        )
        XCTAssertTrue(
            PlanEditWizardStepGate.canAdvance(
                from: .goalAndTargetWeight,
                formState: formState,
                goalType: .gainMuscle,
                goalWeightValidationMessage: nil,
                pacePreview: .empty
            )
        )
    }

    func testWizardFlowIncludesGoalStepFirst() {
        let formState = PlanFormState(profile: PlanMissionControlFixtures.loseProfile)
        let steps = PlanEditWizardFlow.steps(for: formState)

        XCTAssertEqual(steps.first, .goalAndTargetWeight)
        XCTAssertGreaterThan(steps.count, 1)
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
