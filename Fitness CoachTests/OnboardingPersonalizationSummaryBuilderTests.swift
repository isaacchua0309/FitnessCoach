//
//  OnboardingPersonalizationSummaryBuilderTests.swift
//  Fitness CoachTests
//
//  Forma — Personalization summary recap builder tests.
//

import XCTest
@testable import Fitness_Coach

final class OnboardingPersonalizationSummaryBuilderTests: XCTestCase {

    func testRecapCardsForFilledCutOnboarding() {
        let state = filledCutOnboarding()

        let cards = OnboardingPersonalizationSummaryBuilder.recapCards(for: state)
        XCTAssertEqual(cards.count, 5)

        XCTAssertEqual(cards[0].title, FormaProductCopy.Onboarding.V2.Summary.goalLabel)
        XCTAssertTrue(cards[0].value.contains("→"))

        XCTAssertEqual(cards[1].title, FormaProductCopy.Onboarding.V2.Summary.paceLabel)
        XCTAssertTrue(cards[1].value.contains("Moderate"))
        XCTAssertTrue(cards[1].value.contains("kg/week"))

        XCTAssertEqual(cards[2].title, FormaProductCopy.Onboarding.V2.Summary.activityLabel)
        XCTAssertTrue(cards[2].value.contains("Moderately active"))
        XCTAssertTrue(cards[2].value.contains("3 training days/week"))

        XCTAssertEqual(cards[4].title, FormaProductCopy.Onboarding.V2.Summary.motivationLabel)
        XCTAssertEqual(cards[4].value, FormaProductCopy.Onboarding.V2.Summary.motivationDefault)
    }

    func testMotivationAndLoggingRecapLines() {
        var state = filledCutOnboarding()
        state.selectedMotivations = [.confidence, .performance]
        state.loggingPreferences = [.naturalLanguage, .noPressure]

        let cards = OnboardingPersonalizationSummaryBuilder.recapCards(for: state)
        XCTAssertEqual(cards[3].value, "Natural-language logging or No pressure")
        XCTAssertEqual(cards[4].value, "Confidence, Training performance")
    }

    func testFirstInvalidRequiredStepRoutesToBody() {
        var state = filledCutOnboarding()
        state.ageText = ""

        XCTAssertEqual(
            OnboardingPersonalizationSummaryBuilder.firstInvalidRequiredStep(for: state),
            .body
        )
        XCTAssertFalse(OnboardingPersonalizationSummaryBuilder.isReadyToGenerate(for: state))
    }

    // MARK: - Helpers

    private func filledCutOnboarding() -> OnboardingFormState {
        var state = OnboardingFormState()
        state.ageText = "28"
        state.heightCmText = "168"
        state.currentWeightKgText = "82.5"
        state.goalWeightKgText = "75"
        state.sex = .female
        state.activityLevel = .moderatelyActive
        state.trainingFrequencyPerWeekText = "3"
        state.averageStepsText = "5000"
        return state
    }
}
