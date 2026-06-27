//
//  OnboardingPreferencesTests.swift
//  Fitness CoachTests
//
//  Forma — Chip-based optional preferences tests.
//

import XCTest
@testable import Fitness_Coach

final class OnboardingPreferencesTests: XCTestCase {

    func testEmptyPreferencesAllowContinue() {
        let state = OnboardingFormState()
        XCTAssertTrue(state.canAdvance(from: .preferences))
        XCTAssertTrue(state.canAdvanceV3(from: .preferences))
        XCTAssertTrue(state.loggingPreferences.isEmpty)
    }

    func testMultipleDietChipsStoreCommaSeparatedPhrases() {
        var state = OnboardingFormState()
        state.toggleDietChip(.highProtein)
        state.toggleDietChip(.halal)

        XCTAssertEqual(state.selectedDietChips, [.highProtein, .halal])
        XCTAssertEqual(state.dietPreference, "High protein, Halal")
    }

    func testAddLaterChipIsExclusive() {
        var state = OnboardingFormState()
        state.toggleDietChip(.highProtein)
        state.toggleDietChip(.addLater)

        XCTAssertEqual(state.dietPreference, "I'll add later")
        XCTAssertEqual(state.selectedDietChips, [.addLater])

        state.toggleDietChip(.addLater)
        XCTAssertEqual(state.dietPreference, "")
    }

    func testCustomDietPreferenceAppendsToChips() {
        var state = OnboardingFormState()
        state.toggleDietChip(.vegetarian)
        state.customDietPreferenceText = "Gluten free"

        XCTAssertEqual(state.dietPreference, "Vegetarian, Gluten free")
        XCTAssertEqual(state.customDietPreferenceText, "Gluten free")
    }

    func testLoggingStyleBothMapsToPreferences() {
        var state = OnboardingFormState()
        state.selectLoggingStyle(.both)

        XCTAssertEqual(state.loggingStyleChoice, .both)
        XCTAssertEqual(state.loggingPreferences, [.naturalLanguage, .quickTaps])
    }

    func testLoggingStyleCanBeCleared() {
        var state = OnboardingFormState()
        state.selectLoggingStyle(.chatWithCoach)
        state.selectLoggingStyle(nil)

        XCTAssertNil(state.loggingStyleChoice)
        XCTAssertTrue(state.loggingPreferences.isEmpty)
    }

    func testLoggingStyleChatMapsToNaturalLanguage() {
        var state = OnboardingFormState()
        state.selectLoggingStyle(.chatWithCoach)

        XCTAssertEqual(state.loggingPreferences, [.naturalLanguage])
    }
}
