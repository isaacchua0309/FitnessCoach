//
//  OnboardingWeightLossPaceTests.swift
//  Fitness CoachTests
//
//  Forma — Onboarding weight-loss pace calculation, validation, draft restore, and navigation.
//

import XCTest
@testable import Fitness_Coach

final class OnboardingWeightLossPaceTests: XCTestCase {

    private let referenceDate = FormaCalculationTestFixtures.referenceDate
    private let cutWeightKg = 72.0
    private let cutGoalKg = 65.0

    // MARK: - 1. Cut goal + preset ordering

    func testCutGoalGentlePaceYieldsHigherCaloriesAndLowerWeeklyLossThanModerateAndAggressive() throws {
        let gentle = try generatedPlan(paceChoice: .gentle)
        let moderate = try generatedPlan(paceChoice: .moderate)
        let aggressive = try generatedPlan(paceChoice: .aggressive)

        XCTAssertGreaterThan(gentle.targets.calorieTarget, moderate.targets.calorieTarget)
        XCTAssertGreaterThan(moderate.targets.calorieTarget, aggressive.targets.calorieTarget)

        let gentleWeekly = try XCTUnwrap(gentle.targets.expectedWeeklyWeightLossKg)
        let moderateWeekly = try XCTUnwrap(moderate.targets.expectedWeeklyWeightLossKg)
        let aggressiveWeekly = try XCTUnwrap(aggressive.targets.expectedWeeklyWeightLossKg)

        XCTAssertLessThan(gentleWeekly, moderateWeekly)
        XCTAssertLessThan(moderateWeekly, aggressiveWeekly)
    }

    // MARK: - 2. Cut goal + moderate pace

    func testCutGoalModeratePaceGeneratesValidTargetWithExpectedWeeklyLoss() throws {
        let result = try generatedPlan(paceChoice: .moderate)

        XCTAssertGreaterThan(result.targets.calorieTarget, 0)
        XCTAssertGreaterThan(result.estimatedTDEE, result.targets.calorieTarget)
        XCTAssertGreaterThan(result.estimatedDailyDeficit, 0)

        let expectedModerateWeekly = cutWeightKg * WeightLossPreset.moderate.weeklyLossFraction
        XCTAssertEqual(
            result.targets.expectedWeeklyWeightLossKg ?? 0,
            expectedModerateWeekly,
            accuracy: 0.02
        )
        XCTAssertEqual(result.targets.aggressiveness, .moderate)
    }

    // MARK: - 3. Cut goal + aggressive pace

    func testCutGoalAggressivePaceYieldsLowerCaloriesThanGentleAndModerate() throws {
        let gentle = try generatedPlan(paceChoice: .gentle)
        let moderate = try generatedPlan(paceChoice: .moderate)
        let aggressive = try generatedPlan(paceChoice: .aggressive)

        XCTAssertLessThan(aggressive.targets.calorieTarget, gentle.targets.calorieTarget)
        XCTAssertLessThan(aggressive.targets.calorieTarget, moderate.targets.calorieTarget)
    }

    func testCutGoalAggressivePacePreviewShowsDemandingSafety() {
        var state = cutFormState(paceChoice: .aggressive)
        let preview = state.pacePreview(referenceDate: referenceDate)

        XCTAssertTrue(preview.isSaveable)
        XCTAssertEqual(preview.safetyDisplay, .demanding)
        XCTAssertNotNil(preview.warningMessage)
    }

    func testCutGoalAggressivePaceRespectsCalorieFloor() throws {
        var state = OnboardingFormState()
        OnboardingHeightWeightValues.setHeightCm(155, in: &state)
        OnboardingHeightWeightValues.setWeightKg(52, in: &state)
        OnboardingTargetWeightValues.setGoalWeightKg(48, in: &state)
        OnboardingBirthdayValues.applyDefaultsIfNeeded(to: &state)
        state.sex = .female
        OnboardingActivityLevelValues.select(.sedentary, in: &state)
        state.selectPaceChoice(.aggressive)

        let aggressive = try PlanCalculationBridge.calorieTargetResult(
            from: try state.makeCalorieTargetInput(referenceDate: referenceDate)
        )
        state.selectPaceChoice(.gentle)
        let gentle = try PlanCalculationBridge.calorieTargetResult(
            from: try state.makeCalorieTargetInput(referenceDate: referenceDate)
        )

        XCTAssertGreaterThanOrEqual(aggressive.targets.calorieTarget, 1200)
        XCTAssertLessThan(aggressive.targets.calorieTarget, gentle.targets.calorieTarget)
    }

    // MARK: - 4. Cut goal + advanced weekly pace

    func testCutGoalAdvancedWeeklyPaceGeneratesExpectedTarget() throws {
        var state = cutFormState(paceChoice: .advanced)
        state.advancedPaceDraft = WeightLossAdvancedPaceDraft(period: .weekly, amountText: "0.5")

        let result = try PlanCalculationBridge.calorieTargetResult(
            from: try state.makeCalorieTargetInput(referenceDate: referenceDate)
        )

        XCTAssertEqual(result.targets.expectedWeeklyWeightLossKg ?? 0, 0.5, accuracy: 0.02)
        XCTAssertGreaterThan(result.targets.calorieTarget, 0)
        XCTAssertTrue(state.canAdvance(from: .weightLossPace))
    }

    func testCutGoalAdvancedWeeklyBlankAmountBlocksPaceValidation() {
        var state = cutFormState(paceChoice: .advanced)
        state.advancedPaceDraft = WeightLossAdvancedPaceDraft(period: .weekly, amountText: "")

        XCTAssertFalse(state.pacePreview(referenceDate: referenceDate).isSaveable)
        XCTAssertFalse(state.canAdvance(from: .weightLossPace))
        XCTAssertNotNil(state.validationMessage(for: .weightLossPace))
    }

    func testCutGoalAdvancedWeeklyNonNumericAmountBlocksPaceValidation() {
        var state = cutFormState(paceChoice: .advanced)
        state.advancedPaceDraft = WeightLossAdvancedPaceDraft(period: .weekly, amountText: "abc")

        XCTAssertFalse(state.pacePreview(referenceDate: referenceDate).isSaveable)
        XCTAssertFalse(state.canAdvance(from: .weightLossPace))
    }

    func testCutGoalAdvancedWeeklyPaceAboveMaximumBlocksAdvance() {
        var state = cutFormState(paceChoice: .advanced)
        state.advancedPaceDraft = WeightLossAdvancedPaceDraft(period: .weekly, amountText: "1.3")

        XCTAssertFalse(state.pacePreview(referenceDate: referenceDate).isSaveable)
        XCTAssertFalse(state.canAdvance(from: .weightLossPace))
        XCTAssertNotNil(state.validationMessage(for: .weightLossPace))
    }

    func testCutGoalAdvancedWeeklyPaceAtMaximumAllowsAdvance() {
        var state = cutFormState(paceChoice: .advanced)
        state.advancedPaceDraft = WeightLossAdvancedPaceDraft(
            period: .weekly,
            amountText: "1.2"
        )

        XCTAssertTrue(state.pacePreview(referenceDate: referenceDate).isSaveable)
        XCTAssertTrue(state.canAdvance(from: .weightLossPace))
    }

    // MARK: - 5. Cut goal + advanced monthly pace

    func testCutGoalAdvancedMonthlyPaceConvertsToWeeklyEquivalent() throws {
        var state = cutFormState(paceChoice: .advanced)
        state.advancedPaceDraft = WeightLossAdvancedPaceDraft(period: .monthly, amountText: "2.0")

        let preview = state.pacePreview(referenceDate: referenceDate)
        let weeksPerMonth = FormaCalculationConstants.daysPerAverageMonth / 7.0
        let expectedWeekly = 2.0 / weeksPerMonth

        XCTAssertTrue(preview.isSaveable)
        XCTAssertEqual(preview.monthlyLossKg ?? 0, 2.0, accuracy: 0.05)
        XCTAssertEqual(preview.weeklyLossKg ?? 0, expectedWeekly, accuracy: 0.02)

        let result = try PlanCalculationBridge.calorieTargetResult(
            from: try state.makeCalorieTargetInput(referenceDate: referenceDate)
        )
        XCTAssertEqual(result.targets.expectedWeeklyWeightLossKg ?? 0, expectedWeekly, accuracy: 0.02)
    }

    // MARK: - 6. Maintain / gain goals

    func testMaintainGoalDoesNotRequirePaceStep() {
        var state = maintainFormState()
        state.selectPaceChoice(.advanced)
        state.advancedPaceDraft = WeightLossAdvancedPaceDraft(period: .weekly, amountText: "not-a-number")

        XCTAssertFalse(state.isPaceApplicable())
        XCTAssertNotEqual(OnboardingFormState.firstInvalidRequiredStep(for: state), .weightLossPace)
        XCTAssertTrue(state.canAdvance(from: .targetWeight))
        XCTAssertTrue(state.canAdvance(from: .targetEncouragement))
    }

    func testGainGoalDoesNotRequirePaceStep() {
        var state = gainFormState()
        state.selectPaceChoice(.advanced)
        state.advancedPaceDraft = WeightLossAdvancedPaceDraft(period: .weekly, amountText: "")

        XCTAssertFalse(state.isPaceApplicable())
        XCTAssertNotEqual(OnboardingFormState.firstInvalidRequiredStep(for: state), .weightLossPace)
        XCTAssertTrue(state.canAdvance(from: .targetWeight))
    }

    func testMaintainGoalCalculationDoesNotApplyDeficit() throws {
        let result = try PlanCalculationBridge.calorieTargetResult(
            from: try maintainFormState().makeCalorieTargetInput(referenceDate: referenceDate)
        )

        XCTAssertEqual(result.estimatedDailyDeficit, 0)
        XCTAssertEqual(result.targets.calorieTarget, result.estimatedTDEE)
        XCTAssertEqual(result.targets.expectedWeeklyWeightLossKg ?? 0, 0, accuracy: 0.001)
    }

    func testGainGoalCalculationDoesNotApplyDeficit() throws {
        let result = try PlanCalculationBridge.calorieTargetResult(
            from: try gainFormState().makeCalorieTargetInput(referenceDate: referenceDate)
        )

        XCTAssertEqual(result.estimatedDailyDeficit, 0)
        XCTAssertEqual(result.targets.calorieTarget, result.estimatedTDEE)
    }

    // MARK: - 7. Draft restore

    func testDraftRestorePreservesSelectedPaceAndAdvancedDraft() throws {
        var formState = cutFormState(paceChoice: .advanced)
        formState.advancedPaceDraft = WeightLossAdvancedPaceDraft(period: .monthly, amountText: "2.5")

        let draft = OnboardingDraft(formState: formState, step: .weightLossPace)
        let restored = draft.makeFormState()

        XCTAssertEqual(restored.weightLossPaceChoice, .advanced)
        XCTAssertEqual(restored.advancedPaceDraft.period, .monthly)
        XCTAssertEqual(restored.advancedPaceDraft.amountText, "2.5")
        XCTAssertEqual(restored.aggressiveness, WeightLossPaceChoice.advanced.legacyAggressiveness)
    }

    func testDraftRestoreResolvesStalePaceStepForNonCutGoal() {
        var formState = maintainFormState()
        formState.selectPaceChoice(.moderate)

        let restoredStep = OnboardingDraftStepResolver.restoredStep(
            rawValue: OnboardingStep.weightLossPace.rawValue,
            formState: formState,
            flow: OnboardingStep.flow
        )

        XCTAssertEqual(restoredStep, .targetEncouragement)
    }

    func testDraftStoreRoundTripPreservesPaceFields() throws {
        let suiteName = "OnboardingWeightLossPaceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var formState = cutFormState(paceChoice: .gentle)
        let store = OnboardingDraftStore(userDefaults: defaults)
        store.saveDraft(OnboardingDraft(formState: formState, step: .weightLossPace))

        let restored = try XCTUnwrap(store.loadDraft()?.makeFormState())
        XCTAssertEqual(restored.weightLossPaceChoice, .gentle)
    }

    // MARK: - Helpers

    private func cutFormState(paceChoice: WeightLossPaceChoice) -> OnboardingFormState {
        var state = OnboardingFormState()
        OnboardingHeightWeightValues.setHeightCm(168, in: &state)
        OnboardingHeightWeightValues.setWeightKg(cutWeightKg, in: &state)
        OnboardingTargetWeightValues.setGoalWeightKg(cutGoalKg, in: &state)
        OnboardingBirthdayValues.applyDefaultsIfNeeded(to: &state)
        state.sex = .female
        OnboardingActivityLevelValues.select(.moderatelyActive, in: &state)
        state.selectPaceChoice(paceChoice)
        return state
    }

    private func maintainFormState() -> OnboardingFormState {
        var state = OnboardingFormState()
        OnboardingHeightWeightValues.setHeightCm(170, in: &state)
        OnboardingHeightWeightValues.setWeightKg(72, in: &state)
        OnboardingTargetWeightValues.applyDefaultsIfNeeded(to: &state)
        OnboardingBirthdayValues.applyDefaultsIfNeeded(to: &state)
        state.sex = .female
        OnboardingActivityLevelValues.select(.moderatelyActive, in: &state)
        return state
    }

    private func gainFormState() -> OnboardingFormState {
        var state = OnboardingFormState()
        OnboardingHeightWeightValues.setHeightCm(170, in: &state)
        OnboardingHeightWeightValues.setWeightKg(72, in: &state)
        OnboardingTargetWeightValues.setGoalWeightKg(75, in: &state)
        OnboardingBirthdayValues.applyDefaultsIfNeeded(to: &state)
        state.sex = .female
        OnboardingActivityLevelValues.select(.moderatelyActive, in: &state)
        return state
    }

    private func generatedPlan(paceChoice: WeightLossPaceChoice) throws -> CalorieTargetResult {
        try PlanCalculationBridge.calorieTargetResult(
            from: try cutFormState(paceChoice: paceChoice).makeCalorieTargetInput(referenceDate: referenceDate)
        )
    }
}

// MARK: - Navigation

@MainActor
final class OnboardingWeightLossPaceNavigationTests: XCTestCase {

    private var draftDefaults: UserDefaults!
    private var draftStore: OnboardingDraftStore!

    override func setUp() {
        super.setUp()
        draftDefaults = UserDefaults(suiteName: "OnboardingWeightLossPaceNavigationTests.\(UUID().uuidString)")!
        draftStore = OnboardingDraftStore(userDefaults: draftDefaults)
    }

    override func tearDown() {
        draftStore.clearDraft()
        draftDefaults.removePersistentDomain(forName: draftDefaults.description)
        draftDefaults = nil
        draftStore = nil
        super.tearDown()
    }

    func testCutGoalAdvancesFromTargetWeightToPaceStep() throws {
        let model = try makePostAuthModel()
        prepareHeightWeight(&model.formState)
        model.currentStep = .targetWeight
        OnboardingTargetWeightValues.setGoalFromDeltaKg(-5, in: &model.formState)

        model.goNext()

        XCTAssertEqual(model.currentStep, .weightLossPace)
    }

    func testMaintainGoalAdvancesFromTargetWeightToTargetEncouragementSkippingPace() throws {
        let model = try makePostAuthModel()
        prepareHeightWeight(&model.formState)
        model.currentStep = .targetWeight
        OnboardingTargetWeightValues.applyDefaultsIfNeeded(to: &model.formState)

        model.goNext()

        XCTAssertEqual(model.currentStep, .targetEncouragement)
    }

    func testGainGoalAdvancesFromTargetWeightToTargetEncouragementSkippingPace() throws {
        let model = try makePostAuthModel()
        prepareHeightWeight(&model.formState)
        model.currentStep = .targetWeight
        OnboardingTargetWeightValues.setGoalWeightKg(75, in: &model.formState)

        model.goNext()

        XCTAssertEqual(model.currentStep, .targetEncouragement)
    }

    func testCutGoalBackFromTargetEncouragementReturnsToPaceStep() throws {
        let model = try makePostAuthModel()
        prepareCutGoalForm(&model.formState)
        model.currentStep = .targetEncouragement

        model.goBack()

        XCTAssertEqual(model.currentStep, .weightLossPace)
    }

    func testMaintainGoalBackFromTargetEncouragementSkipsPaceStep() throws {
        let model = try makePostAuthModel()
        prepareHeightWeight(&model.formState)
        OnboardingTargetWeightValues.applyDefaultsIfNeeded(to: &model.formState)
        model.currentStep = .targetEncouragement

        model.goBack()

        XCTAssertEqual(model.currentStep, .targetWeight)
    }

    // MARK: - Helpers

    private func makePostAuthModel() throws -> OnboardingModel {
        let container = try AppContainer(inMemory: true)
        return OnboardingModel(
            actionCenter: container.actionCenter,
            userProfileReader: container.userProfileService,
            planTargetCalculator: container.targetService,
            onCompletion: {},
            draftStore: draftStore,
            analyticsEntry: .postAuth,
            generationDelay: ImmediateOnboardingGenerationDelayProvider()
        )
    }

    private func prepareHeightWeight(_ formState: inout OnboardingFormState) {
        OnboardingHeightWeightValues.applyDefaultsIfNeeded(to: &formState)
        formState.sex = .female
    }

    private func prepareCutGoalForm(_ formState: inout OnboardingFormState) {
        prepareHeightWeight(&formState)
        OnboardingTargetWeightValues.setGoalFromDeltaKg(-5, in: &formState)
        formState.selectPaceChoice(.moderate)
    }
}
