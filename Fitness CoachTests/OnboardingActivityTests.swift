//
//  OnboardingActivityTests.swift
//  Fitness CoachTests
//
//  Forma — Tap-first activity and training rhythm chip tests.
//

import XCTest
@testable import Fitness_Coach

final class OnboardingActivityTests: XCTestCase {

    func testEachActivityLevelSelectable() {
        for level in ActivityLevel.allCases {
            var state = OnboardingFormState()
            state.selectActivityLevel(level)
            XCTAssertEqual(state.activityLevel, level)
        }
    }

    func testActivityLevelUpdatesTrainingDefaults() {
        var state = OnboardingFormState()
        state.selectActivityLevel(.sedentary)
        XCTAssertEqual(state.trainingDaysSelection, 0)
        XCTAssertEqual(state.parsedAverageSteps, 3_000)

        state.selectActivityLevel(.athlete)
        XCTAssertEqual(state.trainingDaysSelection, 6)
        XCTAssertEqual(state.parsedAverageSteps, 12_000)
    }

    func testTrainingDaysChipMapping() {
        var state = OnboardingFormState()
        state.trainingDaysChip = .four
        XCTAssertEqual(state.trainingFrequencyPerWeekText, "4")
        XCTAssertEqual(state.trainingDaysChip, .four)

        state.trainingDaysChip = .fivePlus
        XCTAssertEqual(state.trainingFrequencyPerWeekText, "5")
        XCTAssertEqual(state.trainingDaysChip, .fivePlus)
    }

    func testDailyStepsBandMappings() {
        XCTAssertEqual(OnboardingDailyStepsBand.notSure.representativeSteps, 5_000)
        XCTAssertEqual(OnboardingDailyStepsBand.low.representativeSteps, 3_000)
        XCTAssertEqual(OnboardingDailyStepsBand.moderate.representativeSteps, 6_000)
        XCTAssertEqual(OnboardingDailyStepsBand.high.representativeSteps, 9_000)
    }

    func testNotSureStepsBandStoresDefaultValue() {
        var state = OnboardingFormState()
        state.dailyStepsBand = .notSure
        XCTAssertEqual(state.averageStepsText, "5000")
        XCTAssertEqual(state.dailyStepsBand, .notSure)
        XCTAssertTrue(state.canAdvance(from: .activity))
        XCTAssertTrue(state.canAdvanceV3(from: .trainingRhythm))
    }

    func testEnsureTrainingRhythmValuesFillsEmptyFields() {
        var state = OnboardingFormState()
        state.activityLevel = .moderatelyActive
        state.trainingFrequencyPerWeekText = ""
        state.averageStepsText = ""
        state.ensureTrainingRhythmValues()

        XCTAssertEqual(state.trainingFrequencyPerWeekText, "3")
        XCTAssertEqual(state.parsedAverageSteps, 7_500)
    }

    func testV3ActivityLevelAlwaysAllowsContinue() {
        let state = OnboardingFormState()
        XCTAssertTrue(state.canAdvanceV3(from: .activityLevel))
    }
}
