//
//  OnboardingMotivationTests.swift
//  Fitness CoachTests
//
//  Forma — Optional motivation selection and coaching context mapping tests.
//

import XCTest
@testable import Fitness_Coach

final class OnboardingMotivationTests: XCTestCase {

    func testEmptyMotivationNeverBlocksAdvanceOrValidation() {
        var state = OnboardingFormState()

        XCTAssertTrue(OnboardingMotivation.allowsEmptySelection)
        XCTAssertTrue(state.selectedMotivations.isEmpty)
        XCTAssertTrue(state.canAdvance(from: .motivation))
        XCTAssertNil(state.validationMessage(for: .motivation))
    }

    func testSelectedMotivationsMapToCoachingContext() throws {
        var state = OnboardingFormState()
        state.selectedMotivations = [.confidence, .health, .lowStress]

        let context = state.makeCoachingContext()

        XCTAssertEqual(context.motivationSet, state.selectedMotivations)
        XCTAssertEqual(context.motivations, ["confidence", "health", "lowStress"])
    }

    func testMotivationDraftRoundTripPreservesSelections() throws {
        var formState = OnboardingFormState()
        formState.selectedMotivations = [.energy, .discipline]

        let fields = OnboardingDraftFormFields(formState: formState)
        let restored = fields.makeFormState()

        XCTAssertEqual(restored.selectedMotivations, formState.selectedMotivations)
    }

    func testFeedbackMessagePrioritizesConfidenceThenPerformanceThenLowStress() {
        XCTAssertEqual(
            OnboardingMotivation.feedbackMessage(for: [.health, .confidence]),
            FormaProductCopy.Onboarding.V2.Motivation.confidenceFeedback
        )
        XCTAssertEqual(
            OnboardingMotivation.feedbackMessage(for: [.health, .performance]),
            FormaProductCopy.Onboarding.V2.Motivation.performanceFeedback
        )
        XCTAssertEqual(
            OnboardingMotivation.feedbackMessage(for: [.health, .lowStress]),
            FormaProductCopy.Onboarding.V2.Motivation.lowStressFeedback
        )
        XCTAssertEqual(
            OnboardingMotivation.feedbackMessage(for: [.health, .energy]),
            FormaProductCopy.Onboarding.V2.Motivation.defaultFeedback
        )
    }

    func testMotivationDoesNotAffectCalorieTargetInput() throws {
        var without = filledForm()
        var withMotivation = filledForm()
        withMotivation.selectedMotivations = [.performance, .discipline]

        let withoutInput = try without.makeCalorieTargetInput()
        let withInput = try withMotivation.makeCalorieTargetInput()

        XCTAssertEqual(withoutInput, withInput)
    }

    func testMotivationFromStoredValuesDropsUnknownRawValues() {
        let motivations = OnboardingMotivation.fromStoredValues(["health", "other", "energy"])
        XCTAssertEqual(motivations, [.health, .energy])
    }

    func testMotivationCaseCountMatchesProductOptions() {
        XCTAssertEqual(OnboardingMotivation.allCases.count, 6)
    }

    // MARK: - Helpers

    private func filledForm() -> OnboardingFormState {
        var state = OnboardingFormState()
        state.ageText = "28"
        state.sex = .female
        state.heightCmText = "168"
        state.currentWeightKgText = "72"
        state.goalWeightKgText = "65"
        state.activityLevel = .moderatelyActive
        state.trainingFrequencyPerWeekText = "3"
        state.averageStepsText = "5000"
        state.selectPaceChoice(.moderate)
        return state
    }
}
