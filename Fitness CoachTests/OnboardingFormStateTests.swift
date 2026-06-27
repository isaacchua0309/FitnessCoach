//
//  OnboardingFormStateTests.swift
//  Fitness CoachTests
//
//  Stage C2 — Onboarding weight-loss pace integration tests.
//

import XCTest
@testable import Fitness_Coach

final class OnboardingFormStateTests: XCTestCase {

    private let referenceDate = FormaCalculationTestFixtures.referenceDate

    // MARK: - Preset parity

    func testPresetGentleMatchesLegacyConservative() throws {
        try assertPresetParity(
            legacyAggressiveness: .conservative,
            paceChoice: .gentle
        )
    }

    func testPresetModerateMatchesLegacyModerate() throws {
        try assertPresetParity(
            legacyAggressiveness: .moderate,
            paceChoice: .moderate
        )
    }

    func testPresetAggressiveMatchesLegacyAggressive() throws {
        try assertPresetParity(
            legacyAggressiveness: .aggressive,
            paceChoice: .aggressive
        )
    }

    // MARK: - Advanced pace

    func testAdvancedHalfKgPerWeekMatchesPlanEditInput() throws {
        var onboarding = filledCutOnboarding(weight: 84, goal: 78)
        onboarding.selectPaceChoice(.advanced)
        onboarding.advancedPaceDraft = WeightLossAdvancedPaceDraft(
            period: .weekly,
            amountText: "0.5"
        )

        var profileForm = ProfileFormState.defaultDraftValues()
        profileForm.ageText = onboarding.ageText
        profileForm.sex = onboarding.sex
        profileForm.heightCmText = onboarding.heightCmText
        profileForm.currentWeightKgText = onboarding.currentWeightKgText
        profileForm.goalWeightKgText = onboarding.goalWeightKgText
        profileForm.activityLevel = onboarding.activityLevel
        profileForm.trainingFrequencyPerWeekText = onboarding.trainingFrequencyPerWeekText
        profileForm.averageStepsText = onboarding.averageStepsText
        profileForm.weightLossPaceChoice = .advanced
        profileForm.advancedPaceDraft = onboarding.advancedPaceDraft
        profileForm.syncAggressivenessFromPaceChoice()

        let onboardingResult = try PlanCalculationBridge.calorieTargetResult(
            from: try onboarding.makeCalorieTargetInput()
        )
        let profileResult = try PlanCalculationBridge.calorieTargetResult(
            from: try profileForm.makeCalorieTargetInput()
        )

        XCTAssertEqual(onboardingResult, profileResult)
    }

    func testAdvancedMonthlyPacePreviewConvertsWeeklyAndMonthly() throws {
        var state = filledCutOnboarding(weight: 70, goal: 64)
        state.selectPaceChoice(.advanced)
        state.advancedPaceDraft = WeightLossAdvancedPaceDraft(
            period: .monthly,
            amountText: "2.0"
        )

        let preview = state.pacePreview(referenceDate: referenceDate)

        XCTAssertTrue(preview.isSaveable)
        XCTAssertNotNil(preview.weeklyLossKg)
        XCTAssertNotNil(preview.monthlyLossKg)
        XCTAssertEqual(preview.monthlyLossKg ?? 0, 2.0, accuracy: 0.05)
        XCTAssertNotNil(preview.dailyDeficitKcal)
    }

    func testAdvancedInvalidInputBlocksGoalAdvanceAndPlanGeneration() throws {
        var state = filledCutOnboarding()
        state.selectPaceChoice(.advanced)
        state.advancedPaceDraft = WeightLossAdvancedPaceDraft(
            period: .weekly,
            amountText: ""
        )

        XCTAssertFalse(state.pacePreview().isSaveable)
        XCTAssertFalse(state.canAdvance(from: .goal))

        XCTAssertThrowsError(try state.makeCalorieTargetInput())
        XCTAssertThrowsError(
            try PlanCalculationBridge.calorieTargetResult(from: try state.makeCalorieTargetInput())
        )
    }

    func testGeneratedTargetsStoreExpectedWeeklyWeightLossForAdvancedPace() throws {
        var state = filledCutOnboarding(weight: 84, goal: 78)
        state.selectPaceChoice(.advanced)
        state.advancedPaceDraft = WeightLossAdvancedPaceDraft(
            period: .weekly,
            amountText: "0.5"
        )

        let result = try PlanCalculationBridge.calorieTargetResult(
            from: try state.makeCalorieTargetInput()
        )

        XCTAssertNotNil(result.targets.expectedWeeklyWeightLossKg)
        XCTAssertGreaterThan(result.targets.expectedWeeklyWeightLossKg ?? 0, 0)
        XCTAssertEqual(result.targets.aggressiveness, .moderate)
    }

    func testAdvancedPaceCloudProfileDocumentRoundTrip() throws {
        var state = filledCutOnboarding(weight: 84, goal: 78)
        state.selectPaceChoice(.advanced)
        state.advancedPaceDraft = WeightLossAdvancedPaceDraft(
            period: .weekly,
            amountText: "0.5"
        )

        let generated = try PlanCalculationBridge.calorieTargetResult(
            from: try state.makeCalorieTargetInput()
        )
        let draft = try state.makeUserProfileDraft(targets: generated.targets)
        let profile = UserProfile(
            id: UUID(),
            name: draft.name,
            age: draft.age,
            sex: draft.sex,
            heightCm: draft.heightCm,
            currentWeightKg: draft.currentWeightKg,
            goalWeightKg: draft.goalWeightKg,
            estimatedBodyFatPercentage: draft.estimatedBodyFatPercentage,
            activityLevel: draft.activityLevel,
            trainingFrequencyPerWeek: draft.trainingFrequencyPerWeek,
            averageSteps: draft.averageSteps,
            dietPreference: draft.dietPreference,
            unitSystem: draft.unitSystem,
            targets: draft.targets,
            createdAt: referenceDate,
            updatedAt: referenceDate
        )

        let document = CloudUserProfileDocument(
            profile: profile,
            onboardingCompletedAt: referenceDate,
            updatedAt: referenceDate
        )
        let restored = document.makeUserProfile()

        XCTAssertEqual(
            restored.targets.expectedWeeklyWeightLossKg,
            generated.targets.expectedWeeklyWeightLossKg
        )
        XCTAssertEqual(restored.targets.aggressiveness, generated.targets.aggressiveness)

        let inferred = WeightLossPaceChoiceResolver.infer(
            aggressiveness: restored.targets.aggressiveness,
            expectedWeeklyLossKg: restored.targets.expectedWeeklyWeightLossKg,
            weightKg: restored.currentWeightKg,
            goalWeightKg: restored.goalWeightKg
        )
        XCTAssertEqual(inferred.choice, .advanced)
    }

    // MARK: - V2 optional fields

    func testEmptyMotivationDoesNotBlockAdvanceOrCalculation() throws {
        var state = OnboardingFormState()
        XCTAssertTrue(state.selectedMotivations.isEmpty)
        XCTAssertTrue(state.canAdvance(from: .motivation))
        XCTAssertNil(state.validationMessage(for: .motivation))

        state = filledCutOnboarding()
        _ = try state.makeCalorieTargetInput()
    }

    func testEmptyLoggingPreferencesDoNotBlockAdvanceOrCalculation() throws {
        var state = OnboardingFormState()
        XCTAssertTrue(state.loggingPreferences.isEmpty)
        XCTAssertTrue(state.canAdvance(from: .preferences))
        XCTAssertNil(state.validationMessage(for: .preferences))

        state = filledCutOnboarding()
        _ = try state.makeCalorieTargetInput()
    }

    func testOptionalDietPreferenceDoesNotBreakCalorieTargetInput() throws {
        var state = filledCutOnboarding()
        state.dietPreference = "No shellfish, prefer high protein"

        let input = try state.makeCalorieTargetInput()
        let result = try PlanCalculationBridge.calorieTargetResult(from: input)

        XCTAssertGreaterThan(result.targets.calorieTarget, 0)
    }

    func testOptionalPreferencesAndDietNotesDoNotChangeTargetMath() throws {
        var baseline = filledCutOnboarding()
        var withPreferences = filledCutOnboarding()
        withPreferences.loggingPreferences = [.naturalLanguage, .dailyCheckIns]
        withPreferences.dietPreference = "Gluten free"

        let baselineResult = try PlanCalculationBridge.calorieTargetResult(
            from: try baseline.makeCalorieTargetInput()
        )
        let withPreferencesResult = try PlanCalculationBridge.calorieTargetResult(
            from: try withPreferences.makeCalorieTargetInput()
        )

        XCTAssertEqual(baselineResult, withPreferencesResult)
    }

    func testRequiredBodyFieldsStillBlockAdvance() {
        var state = OnboardingFormState()
        XCTAssertFalse(state.canAdvance(from: .body))
        XCTAssertNotNil(state.validationMessage(for: .body))

        state.ageText = "28"
        state.heightCmText = "168"
        state.currentWeightKgText = "72"
        XCTAssertTrue(state.canAdvance(from: .body))
    }

    func testBodyFatBlankAllowsAdvance() {
        var state = filledBodyBasics()
        state.estimatedBodyFatPercentageText = ""
        XCTAssertTrue(state.canAdvance(from: .body))
        XCTAssertNil(state.validationMessage(for: .body))
    }

    func testBodyFatAccepts24() throws {
        var state = filledBodyBasics()
        state.estimatedBodyFatPercentageText = "24"
        XCTAssertTrue(state.canAdvance(from: .body))
        XCTAssertNoThrow(try state.validate(step: .body))

        var full = filledCutOnboarding()
        full.estimatedBodyFatPercentageText = "24"
        let input = try full.makeCalorieTargetInput()
        XCTAssertEqual(input.estimatedBodyFatPercentage, 24)
    }

    func testBodyFatAccepts24Percent() throws {
        var state = filledBodyBasics()
        state.estimatedBodyFatPercentageText = "24%"
        XCTAssertTrue(state.canAdvance(from: .body))
        XCTAssertNoThrow(try state.validate(step: .body))

        var full = filledCutOnboarding()
        full.estimatedBodyFatPercentageText = "24%"
        let input = try full.makeCalorieTargetInput()
        XCTAssertEqual(input.estimatedBodyFatPercentage, 24)
    }

    func testBodyFatAcceptsBoundaryValues() throws {
        var low = filledBodyBasics()
        low.estimatedBodyFatPercentageText = "3"
        XCTAssertTrue(low.canAdvance(from: .body))

        var high = filledBodyBasics()
        high.estimatedBodyFatPercentageText = "70"
        XCTAssertTrue(high.canAdvance(from: .body))

        var fullLow = filledCutOnboarding()
        fullLow.estimatedBodyFatPercentageText = "3"
        XCTAssertEqual(try fullLow.makeCalorieTargetInput().estimatedBodyFatPercentage, 3)

        var fullHigh = filledCutOnboarding()
        fullHigh.estimatedBodyFatPercentageText = "70"
        XCTAssertEqual(try fullHigh.makeCalorieTargetInput().estimatedBodyFatPercentage, 70)
    }

    func testBodyFatRejectsBelowMinimum() {
        var state = filledBodyBasics()
        state.estimatedBodyFatPercentageText = "2"
        XCTAssertFalse(state.canAdvance(from: .body))
        XCTAssertEqual(
            state.validationMessage(for: .body),
            FormaProductCopy.Onboarding.Validation.bodyFatRange
        )
    }

    func testBodyFatRejectsAboveMaximum() {
        var state = filledBodyBasics()
        state.estimatedBodyFatPercentageText = "71"
        XCTAssertFalse(state.canAdvance(from: .body))
        XCTAssertEqual(
            state.validationMessage(for: .body),
            FormaProductCopy.Onboarding.Validation.bodyFatRange
        )
    }

    func testBodyFatRejectsNonNumericValues() {
        var state = filledBodyBasics()
        state.estimatedBodyFatPercentageText = "abc"
        XCTAssertFalse(state.canAdvance(from: .body))
        XCTAssertEqual(
            state.validationMessage(for: .body),
            FormaProductCopy.Onboarding.Validation.bodyFatRange
        )
    }

    func testBodyFatInvalidBlocksAdvanceWhenNonEmpty() {
        var state = filledBodyBasics()
        state.estimatedBodyFatPercentageText = "100"
        XCTAssertFalse(state.canAdvance(from: .body))
        XCTAssertNotNil(state.validationMessage(for: .body))
    }

    func testNormalizedBodyFatTextStripsPercentSuffix() {
        XCTAssertEqual(OnboardingFormState.normalizedBodyFatText("24%"), "24")
        XCTAssertEqual(OnboardingFormState.normalizedBodyFatText(" 24 % "), "24")
    }

    func testRequiredGoalFieldsStillBlockAdvance() {
        var state = filledCutOnboarding()
        state.goalWeightKgText = ""
        XCTAssertFalse(state.canAdvance(from: .goal))
        XCTAssertNotNil(state.validationMessage(for: .goal))
    }

    func testRequiredActivityFieldsStillBlockAdvance() {
        var state = filledCutOnboarding()
        state.trainingFrequencyPerWeekText = ""
        XCTAssertFalse(state.canAdvance(from: .activity))
        XCTAssertNotNil(state.validationMessage(for: .activity))

        state.trainingFrequencyPerWeekText = "3"
        state.averageStepsText = ""
        XCTAssertFalse(state.canAdvance(from: .activity))
        XCTAssertNotNil(state.validationMessage(for: .activity))
    }

    func testMakeCalorieTargetInputWorksForValidDraft() throws {
        let state = filledCutOnboarding()
        let input = try state.makeCalorieTargetInput()

        XCTAssertEqual(input.age, 28)
        XCTAssertEqual(input.sex, .female)
        XCTAssertEqual(input.heightCm, 168)
        XCTAssertEqual(input.weightKg, 72)
        XCTAssertEqual(input.goalWeightKg, 65)
        XCTAssertEqual(input.activityLevel, .moderatelyActive)
        XCTAssertEqual(input.trainingFrequencyPerWeek, 3)
        XCTAssertEqual(input.averageSteps, 5000)
    }

    func testMakeCoachingContextSerializesMotivationsAndLoggingPreferences() throws {
        var state = filledCutOnboarding()
        state.selectedMotivations = [.health, .energy]
        state.loggingPreferences = [.naturalLanguage, .noPressure]

        let capturedAt = referenceDate
        let context = state.makeCoachingContext(capturedAt: capturedAt)

        XCTAssertEqual(context.motivations, ["energy", "health"])
        XCTAssertEqual(context.loggingPreferences, ["naturalLanguage", "noPressure"])
        XCTAssertEqual(context.capturedAt, capturedAt)
        XCTAssertEqual(context.motivationSet, state.selectedMotivations)
        XCTAssertEqual(context.loggingPreferenceSet, state.loggingPreferences)

        let encoded = try JSONEncoder().encode(context)
        let decoded = try JSONDecoder().decode(OnboardingCoachingContext.self, from: encoded)
        XCTAssertEqual(decoded, context)
    }

    func testDisplayUnitHelpersConvertWithoutChangingMetricStorage() {
        var state = OnboardingFormState()
        state.heightCmText = "180"
        state.currentWeightKgText = "80"
        state.displayUnitSystem = .imperial

        let imperialWeight = state.displayText(for: .currentWeight)
        state.setDisplayText(imperialWeight, for: .currentWeight)
        XCTAssertEqual(Double(state.currentWeightKgText) ?? 0, 80, accuracy: 0.1)

        let imperialHeight = state.displayText(for: .height)
        state.setDisplayText(imperialHeight, for: .height)
        XCTAssertEqual(Double(state.heightCmText) ?? 0, 180, accuracy: 0.5)
    }

    func testPreviewDataRemainsValid() throws {
        let state = OnboardingPreviewData.formState
        XCTAssertTrue(state.canAdvance(from: .body))
        XCTAssertTrue(state.canAdvance(from: .goal))
        XCTAssertTrue(state.canAdvance(from: .activity))
        _ = try state.makeCalorieTargetInput()
    }

    // MARK: - Activity training rhythm defaults

    func testChangingActivityUpdatesBothFieldsWhenUntouched() {
        var state = OnboardingFormState()

        state.selectActivityLevel(.sedentary)
        XCTAssertEqual(state.trainingFrequencyPerWeekText, "0")
        XCTAssertEqual(state.averageStepsText, "3000")

        state.selectActivityLevel(.lightlyActive)
        XCTAssertEqual(state.trainingFrequencyPerWeekText, "1")
        XCTAssertEqual(state.averageStepsText, "5000")

        state.selectActivityLevel(.veryActive)
        XCTAssertEqual(state.trainingFrequencyPerWeekText, "5")
        XCTAssertEqual(state.averageStepsText, "10000")

        state.selectActivityLevel(.athlete)
        XCTAssertEqual(state.trainingFrequencyPerWeekText, "6")
        XCTAssertEqual(state.averageStepsText, "12000")
    }

    func testManualTrainingDaysEditPreventsFutureAutoOverwriteOfTrainingDays() {
        var state = OnboardingFormState()
        state.selectActivityLevel(.moderatelyActive)
        state.setTrainingFrequencyPerWeekText("4")

        state.selectActivityLevel(.veryActive)

        XCTAssertEqual(state.trainingFrequencyPerWeekText, "4")
        XCTAssertEqual(state.averageStepsText, "10000")
    }

    func testManualStepsEditPreventsFutureAutoOverwriteOfSteps() {
        var state = OnboardingFormState()
        state.selectActivityLevel(.moderatelyActive)
        state.setAverageStepsText("9000")

        state.selectActivityLevel(.veryActive)

        XCTAssertEqual(state.trainingFrequencyPerWeekText, "5")
        XCTAssertEqual(state.averageStepsText, "9000")
    }

    func testManualStepsEditStillAllowsTrainingDaysToAutoUpdate() {
        var state = OnboardingFormState()
        state.selectActivityLevel(.moderatelyActive)
        state.setAverageStepsText("9000")

        state.selectActivityLevel(.sedentary)

        XCTAssertEqual(state.trainingFrequencyPerWeekText, "0")
        XCTAssertEqual(state.averageStepsText, "9000")
    }

    func testManualTrainingDaysEditStillAllowsStepsToAutoUpdate() {
        var state = OnboardingFormState()
        state.selectActivityLevel(.moderatelyActive)
        state.setTrainingFrequencyPerWeekText("4")

        state.selectActivityLevel(.sedentary)

        XCTAssertEqual(state.trainingFrequencyPerWeekText, "4")
        XCTAssertEqual(state.averageStepsText, "3000")
    }

    func testMakeCalorieTargetInputStillWorksAfterActivityRhythmChanges() throws {
        var state = filledCutOnboarding()
        state.selectActivityLevel(.athlete)
        state.setAverageStepsText("11000")

        let input = try state.makeCalorieTargetInput()
        let result = try PlanCalculationBridge.calorieTargetResult(from: input)

        XCTAssertEqual(input.activityLevel, .athlete)
        XCTAssertEqual(input.trainingFrequencyPerWeek, 6)
        XCTAssertEqual(input.averageSteps, 11_000)
        XCTAssertGreaterThan(result.targets.calorieTarget, 0)
    }

    func testDraftRestoreMarksCustomTrainingRhythmAsManuallyEdited() {
        var fields = OnboardingDraftFormFields(formState: OnboardingFormState())
        fields.activityLevelRawValue = ActivityLevel.moderatelyActive.rawValue
        fields.trainingFrequencyPerWeekText = "4"
        fields.averageStepsText = "9000"

        let restored = fields.makeFormState()

        XCTAssertTrue(restored.hasManuallyEditedTrainingDays)
        XCTAssertTrue(restored.hasManuallyEditedAverageSteps)
        XCTAssertEqual(restored.trainingFrequencyPerWeekText, "4")
        XCTAssertEqual(restored.averageStepsText, "9000")
    }

    // MARK: - Helpers

    private func assertPresetParity(
        legacyAggressiveness: CalorieAggressiveness,
        paceChoice: WeightLossPaceChoice
    ) throws {
        let state = filledCutOnboarding(paceChoice: paceChoice)

        let legacyInput = CalorieTargetInput(
            age: 28,
            sex: .female,
            heightCm: 168,
            weightKg: 72,
            goalWeightKg: 65,
            estimatedBodyFatPercentage: nil,
            activityLevel: .moderatelyActive,
            trainingFrequencyPerWeek: 3,
            averageSteps: 5000,
            aggressiveness: legacyAggressiveness,
            weightLossPace: nil
        )

        let newInput = try state.makeCalorieTargetInput()
        let legacyResult = try PlanCalculationBridge.calorieTargetResult(from: legacyInput)
        let newResult = try PlanCalculationBridge.calorieTargetResult(from: newInput)

        XCTAssertEqual(legacyResult, newResult)
    }

    private func filledBodyBasics() -> OnboardingFormState {
        var state = OnboardingFormState()
        state.ageText = "28"
        state.sex = .female
        state.heightCmText = "168"
        state.currentWeightKgText = "72"
        return state
    }

    private func filledCutOnboarding(
        weight: Double = 72,
        goal: Double = 65,
        paceChoice: WeightLossPaceChoice = .moderate
    ) -> OnboardingFormState {
        var state = OnboardingFormState()
        state.ageText = "28"
        state.sex = .female
        state.heightCmText = "168"
        state.currentWeightKgText = String(weight)
        state.goalWeightKgText = String(goal)
        state.activityLevel = .moderatelyActive
        state.trainingFrequencyPerWeekText = "3"
        state.averageStepsText = "5000"
        state.selectPaceChoice(paceChoice)
        return state
    }
}
