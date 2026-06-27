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
