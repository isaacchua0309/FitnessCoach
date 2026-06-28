//
//  OnboardingV4ActivityTests.swift
//  Fitness CoachTests
//
//  Forma — V4 activity mode selection and validation tests.
//

import XCTest
@testable import Fitness_Coach

final class OnboardingV4ActivityTests: XCTestCase {

    func testV4FlowDoesNotIncludeTrainingRhythmStep() {
        let flowStepNames = OnboardingV4Step.fullFlow.map {
            OnboardingV4DraftBridge.analyticsStepName($0)
        }
        XCTAssertFalse(flowStepNames.contains("trainingRhythm"))
    }

    func testV4ActivityStepUsesDedicatedCopy() {
        XCTAssertEqual(
            OnboardingV4Step.activityLevel.title,
            FormaProductCopy.Onboarding.V4.Activity.title
        )
        XCTAssertEqual(
            OnboardingV4Step.activityLevel.subtitle,
            FormaProductCopy.Onboarding.V4.Activity.subtitle
        )
    }

    func testV4ActivityOptionDescriptionsMatchProductCopy() {
        XCTAssertEqual(
            OnboardingV4ActivityLevelValues.optionDescription(for: .sedentary),
            FormaProductCopy.Onboarding.V4.Activity.sedentaryDescription
        )
        XCTAssertEqual(
            OnboardingV4ActivityLevelValues.optionDescription(for: .lightlyActive),
            FormaProductCopy.Onboarding.V4.Activity.lightlyActiveDescription
        )
        XCTAssertEqual(
            OnboardingV4ActivityLevelValues.optionDescription(for: .moderatelyActive),
            FormaProductCopy.Onboarding.V4.Activity.moderatelyActiveDescription
        )
        XCTAssertEqual(
            OnboardingV4ActivityLevelValues.optionDescription(for: .veryActive),
            FormaProductCopy.Onboarding.V4.Activity.veryActiveDescription
        )
        XCTAssertEqual(
            OnboardingV4ActivityLevelValues.optionDescription(for: .athlete),
            FormaProductCopy.Onboarding.V4.Activity.extraActiveDescription
        )
    }

    func testV4ActivityRoutesNextToAppleHealth() {
        let flow = OnboardingV4Step.fullFlow
        XCTAssertEqual(OnboardingV4Step.activityLevel.next(in: flow), .appleHealth)
    }

    func testV4DoesNotRequireManualTrainingRhythmFields() {
        var state = OnboardingFormState()
        state.activityLevel = .moderatelyActive
        state.trainingFrequencyPerWeekText = ""
        state.averageStepsText = ""

        XCTAssertTrue(state.canAdvanceV4(from: .activityLevel))
        XCTAssertNil(state.validationMessageV4(for: .activityLevel))
    }

    func testV4ApplyDefaultsIfNeededWritesHiddenTrainingRhythmFields() {
        var state = OnboardingFormState()
        state.activityLevel = .lightlyActive
        state.trainingFrequencyPerWeekText = ""
        state.averageStepsText = ""

        OnboardingV4ActivityLevelValues.applyDefaultsIfNeeded(to: &state)

        XCTAssertEqual(state.parsedTrainingDays, 1)
        XCTAssertEqual(state.parsedAverageSteps, 5_000)
    }

    func testV4SedentarySelectionMapsToDefaults() {
        assertActivitySelectionMapsToDefaults(
            level: .sedentary,
            expectedDays: 0,
            expectedSteps: 3_000
        )
    }

    func testV4LightlyActiveSelectionMapsToDefaults() {
        assertActivitySelectionMapsToDefaults(
            level: .lightlyActive,
            expectedDays: 1,
            expectedSteps: 5_000
        )
    }

    func testV4ModeratelyActiveSelectionMapsToDefaults() {
        assertActivitySelectionMapsToDefaults(
            level: .moderatelyActive,
            expectedDays: 3,
            expectedSteps: 7_500
        )
    }

    func testV4VeryActiveSelectionMapsToDefaults() {
        assertActivitySelectionMapsToDefaults(
            level: .veryActive,
            expectedDays: 5,
            expectedSteps: 10_000
        )
    }

    func testV4ExtraActiveSelectionMapsToDefaults() {
        assertActivitySelectionMapsToDefaults(
            level: .athlete,
            expectedDays: 6,
            expectedSteps: 12_000
        )
        XCTAssertEqual(OnboardingFormatter.activityLevel(.athlete), "Extra Active")
    }

    func testV4ActivitySelectionReplacesPreviousSelection() {
        var state = OnboardingFormState()
        OnboardingV4ActivityLevelValues.select(.sedentary, in: &state)
        OnboardingV4ActivityLevelValues.select(.veryActive, in: &state)

        XCTAssertEqual(state.activityLevel, .veryActive)
        XCTAssertEqual(state.parsedTrainingDays, 5)
        XCTAssertEqual(state.parsedAverageSteps, 10_000)
    }

    func testAthleteRawValueDisplaysAsExtraActiveInOnboarding() {
        XCTAssertEqual(OnboardingFormatter.activityLevel(.athlete), "Extra Active")
        XCTAssertEqual(ActivityLevel.athlete.rawValue, "athlete")
    }

    func testV3StillRequiresTrainingRhythmFields() {
        var state = OnboardingFormState()
        state.ageText = "28"
        state.heightCmText = "170"
        state.currentWeightKgText = "70"
        state.goalWeightKgText = "65"
        state.activityLevel = .moderatelyActive
        state.trainingFrequencyPerWeekText = ""
        state.averageStepsText = ""

        XCTAssertFalse(state.canAdvanceV3(from: .trainingRhythm))
        XCTAssertNotNil(state.validationMessageV3(for: .trainingRhythm))
        XCTAssertEqual(
            OnboardingFormState.firstInvalidRequiredV3Step(for: state),
            .trainingRhythm
        )
    }

    func testV3ActivityLevelStepUnchangedWithoutForcedDefaults() {
        var state = OnboardingFormState()
        state.selectActivityLevel(.sedentary)
        state.setTrainingFrequencyPerWeekText("4")

        state.selectActivityLevel(.veryActive)

        XCTAssertEqual(state.parsedTrainingDays, 4)
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

        OnboardingV4ActivityLevelValues.select(level, in: &state)

        XCTAssertEqual(state.activityLevel, level, file: file, line: line)
        XCTAssertEqual(state.parsedTrainingDays, expectedDays, file: file, line: line)
        XCTAssertEqual(state.parsedAverageSteps, expectedSteps, file: file, line: line)
        XCTAssertEqual(
            OnboardingV4ActivityLevelValues.expectedDefaults(for: level).trainingDaysPerWeek,
            expectedDays,
            file: file,
            line: line
        )
        XCTAssertEqual(
            OnboardingV4ActivityLevelValues.expectedDefaults(for: level).averageStepsPerDay,
            expectedSteps,
            file: file,
            line: line
        )
    }
}
