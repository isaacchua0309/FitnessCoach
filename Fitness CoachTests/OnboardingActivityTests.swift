//
//  OnboardingActivityTests.swift
//  Fitness CoachTests
//
//  Forma — activity mode selection and validation tests.
//

import XCTest
@testable import Fitness_Coach

final class OnboardingActivityTests: XCTestCase {

    func testFlowDoesNotIncludeTrainingRhythmStep() {
        let flowStepNames = OnboardingStep.flow.map {
            OnboardingDraftBridge.analyticsStepName($0)
        }
        XCTAssertFalse(flowStepNames.contains("training_rhythm"))
        XCTAssertFalse(flowStepNames.contains("trainingRhythm"))
        XCTAssertFalse(flowStepNames.contains("preferences"))
        XCTAssertFalse(flowStepNames.contains("motivation"))
    }

    func testActivityStepUsesDedicatedCopy() {
        XCTAssertEqual(
            OnboardingStep.activityLevel.title,
            FormaProductCopy.Onboarding.Flow.Activity.title
        )
        XCTAssertEqual(
            OnboardingStep.activityLevel.subtitle,
            FormaProductCopy.Onboarding.Flow.Activity.subtitle
        )
    }

    func testActivityOptionDescriptionsMatchProductCopy() {
        XCTAssertEqual(
            OnboardingActivityLevelValues.optionDescription(for: .sedentary),
            FormaProductCopy.Onboarding.Flow.Activity.sedentaryDescription
        )
        XCTAssertEqual(
            OnboardingActivityLevelValues.optionDescription(for: .lightlyActive),
            FormaProductCopy.Onboarding.Flow.Activity.lightlyActiveDescription
        )
        XCTAssertEqual(
            OnboardingActivityLevelValues.optionDescription(for: .moderatelyActive),
            FormaProductCopy.Onboarding.Flow.Activity.moderatelyActiveDescription
        )
        XCTAssertEqual(
            OnboardingActivityLevelValues.optionDescription(for: .veryActive),
            FormaProductCopy.Onboarding.Flow.Activity.veryActiveDescription
        )
        XCTAssertEqual(
            OnboardingActivityLevelValues.optionDescription(for: .athlete),
            FormaProductCopy.Onboarding.Flow.Activity.extraActiveDescription
        )
    }

    func testActivityRoutesNextToAppleHealth() {
        let flow = OnboardingStep.flow
        XCTAssertEqual(OnboardingStep.activityLevel.next(in: flow), .appleHealth)
    }

    func testDoesNotRequireManualTrainingRhythmFields() {
        var state = OnboardingFormState()
        state.activityLevel = .moderatelyActive
        state.trainingFrequencyPerWeekText = ""
        state.averageStepsText = ""

        XCTAssertTrue(state.canAdvance(from: .activityLevel))
        XCTAssertNil(state.validationMessage(for: .activityLevel))
    }

    func testApplyDefaultsIfNeededWritesHiddenTrainingRhythmFields() {
        var state = OnboardingFormState()
        state.activityLevel = .lightlyActive
        state.trainingFrequencyPerWeekText = ""
        state.averageStepsText = ""

        OnboardingActivityLevelValues.applyDefaultsIfNeeded(to: &state)

        XCTAssertEqual(state.parsedTrainingDays, 1)
        XCTAssertEqual(state.parsedAverageSteps, 5_000)
    }

    func testSedentarySelectionMapsToDefaults() {
        assertActivitySelectionMapsToDefaults(
            level: .sedentary,
            expectedDays: 0,
            expectedSteps: 3_000
        )
    }

    func testLightlyActiveSelectionMapsToDefaults() {
        assertActivitySelectionMapsToDefaults(
            level: .lightlyActive,
            expectedDays: 1,
            expectedSteps: 5_000
        )
    }

    func testModeratelyActiveSelectionMapsToDefaults() {
        assertActivitySelectionMapsToDefaults(
            level: .moderatelyActive,
            expectedDays: 3,
            expectedSteps: 7_500
        )
    }

    func testVeryActiveSelectionMapsToDefaults() {
        assertActivitySelectionMapsToDefaults(
            level: .veryActive,
            expectedDays: 5,
            expectedSteps: 10_000
        )
    }

    func testExtraActiveSelectionMapsToDefaults() {
        assertActivitySelectionMapsToDefaults(
            level: .athlete,
            expectedDays: 6,
            expectedSteps: 12_000
        )
        XCTAssertEqual(OnboardingFormatter.activityLevel(.athlete), "Extra Active")
    }

    func testActivitySelectionReplacesPreviousSelection() {
        var state = OnboardingFormState()
        OnboardingActivityLevelValues.select(.sedentary, in: &state)
        OnboardingActivityLevelValues.select(.veryActive, in: &state)

        XCTAssertEqual(state.activityLevel, .veryActive)
        XCTAssertEqual(state.parsedTrainingDays, 5)
        XCTAssertEqual(state.parsedAverageSteps, 10_000)
    }

    func testAthleteRawValueDisplaysAsExtraActiveInOnboarding() {
        XCTAssertEqual(OnboardingFormatter.activityLevel(.athlete), "Extra Active")
        XCTAssertEqual(ActivityLevel.athlete.rawValue, "athlete")
    }

    private func assertActivitySelectionMapsToDefaults(
        level: ActivityLevel,
        expectedDays: Int,
        expectedSteps: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        var state = OnboardingFormState()
        state.trainingFrequencyPerWeekText = ""
        state.averageStepsText = ""

        OnboardingActivityLevelValues.select(level, in: &state)

        XCTAssertEqual(state.activityLevel, level, file: file, line: line)
        XCTAssertEqual(state.parsedTrainingDays, expectedDays, file: file, line: line)
        XCTAssertEqual(state.parsedAverageSteps, expectedSteps, file: file, line: line)
        XCTAssertEqual(
            OnboardingActivityLevelValues.expectedDefaults(for: level).trainingDaysPerWeek,
            expectedDays,
            file: file,
            line: line
        )
        XCTAssertEqual(
            OnboardingActivityLevelValues.expectedDefaults(for: level).averageStepsPerDay,
            expectedSteps,
            file: file,
            line: line
        )
    }
}
