//
//  OnboardingActivityTests.swift
//  Fitness CoachTests
//
//  Forma — activity mode selection and validation tests.
//

import XCTest
@testable import Fitness_Coach

final class OnboardingActivityTests: XCTestCase {

    func testCanonicalFlowDoesNotIncludeManualRhythmOrMotivationSteps() {
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
            "How active are you?"
        )
        XCTAssertEqual(
            OnboardingStep.activityLevel.subtitle,
            "This helps us estimate your daily calorie target."
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

    func testActivityStepDoesNotRequireManualStepsOrGymSessionInput() {
        var state = OnboardingFormState()
        OnboardingActivityLevelValues.select(.moderatelyActive, in: &state)
        state.trainingFrequencyPerWeekText = ""
        state.averageStepsText = ""

        XCTAssertTrue(state.canAdvance(from: .activityLevel))
        XCTAssertNil(state.validationMessage(for: .activityLevel))
    }

    func testContinueDisabledUntilActivitySelected() {
        var state = OnboardingFormState()

        XCTAssertFalse(state.canAdvance(from: .activityLevel))
        XCTAssertEqual(
            state.validationMessage(for: .activityLevel),
            FormaProductCopy.Onboarding.Flow.Activity.selectionRequiredMessage
        )
    }

    func testTappingSameActivityKeepsSelectionConfirmed() {
        var state = OnboardingFormState()
        OnboardingActivityLevelValues.select(.moderatelyActive, in: &state)
        OnboardingActivityLevelValues.select(.moderatelyActive, in: &state)

        XCTAssertTrue(state.hasConfirmedActivityLevelSelection)
        XCTAssertEqual(state.activityLevel, .moderatelyActive)
        XCTAssertTrue(state.canAdvance(from: .activityLevel))
    }

    func testDraftRoundTripPersistsActivitySelectionConfirmation() {
        var formState = OnboardingFormState()
        OnboardingActivityLevelValues.select(.veryActive, in: &formState)

        let draft = OnboardingDraft(formState: formState, step: .activityLevel)
        let restored = draft.makeFormState()

        XCTAssertEqual(restored.activityLevel, .veryActive)
        XCTAssertTrue(restored.hasConfirmedActivityLevelSelection)
        XCTAssertTrue(restored.canAdvance(from: .activityLevel))
    }

    func testRestoredDraftPastActivityStepInfersConfirmation() {
        var formState = OnboardingFormState()
        formState.activityLevel = .lightlyActive

        let draft = OnboardingDraft(formState: formState, step: .appleHealth)
        let restored = draft.makeFormState()

        XCTAssertTrue(restored.hasConfirmedActivityLevelSelection)
    }

    func testExplanationPlaceholderWhenUnselected() {
        let state = OnboardingActivityLevelExplanationBuilder.build(from: OnboardingFormState())

        XCTAssertTrue(state.isPlaceholder)
        XCTAssertEqual(
            state.headline,
            FormaProductCopy.Onboarding.Flow.Activity.explanationPlaceholder
        )
        XCTAssertEqual(
            FormaProductCopy.Onboarding.Flow.Activity.explanationPlaceholder,
            "Choose the option that best matches a typical week."
        )
    }

    func testSelectedExplanationForEachActivityLevel() {
        let expectations: [(ActivityLevel, String)] = [
            (.sedentary, FormaProductCopy.Onboarding.Flow.Activity.sedentaryExplanationHeadline),
            (.lightlyActive, FormaProductCopy.Onboarding.Flow.Activity.lightlyActiveExplanationHeadline),
            (.moderatelyActive, FormaProductCopy.Onboarding.Flow.Activity.moderatelyActiveExplanationHeadline),
            (.veryActive, FormaProductCopy.Onboarding.Flow.Activity.veryActiveExplanationHeadline),
            (.athlete, FormaProductCopy.Onboarding.Flow.Activity.extraActiveExplanationHeadline),
        ]

        for (level, expected) in expectations {
            XCTAssertEqual(
                OnboardingActivityLevelExplanationBuilder.selectedExplanation(for: level),
                expected
            )
        }
    }

    func testExplanationUpdatesForSelectedLevel() {
        var state = OnboardingFormState()
        OnboardingActivityLevelValues.select(.moderatelyActive, in: &state)

        let explanation = OnboardingActivityLevelExplanationBuilder.build(from: state)

        XCTAssertFalse(explanation.isPlaceholder)
        XCTAssertEqual(
            explanation.headline,
            FormaProductCopy.Onboarding.Flow.Activity.moderatelyActiveExplanationHeadline
        )
    }

    func testSwitchingSelectionUpdatesSelectedExplanation() {
        var state = OnboardingFormState()
        OnboardingActivityLevelValues.select(.sedentary, in: &state)

        XCTAssertEqual(
            OnboardingActivityLevelExplanationBuilder.selectedExplanation(for: state.activityLevel),
            FormaProductCopy.Onboarding.Flow.Activity.sedentaryExplanationHeadline
        )

        OnboardingActivityLevelValues.select(.veryActive, in: &state)

        XCTAssertEqual(
            OnboardingActivityLevelExplanationBuilder.selectedExplanation(for: state.activityLevel),
            FormaProductCopy.Onboarding.Flow.Activity.veryActiveExplanationHeadline
        )
    }

    func testVoiceOverReportsSelectedState() {
        let label = OnboardingActivityLevelExplanationBuilder.voiceOverLabel(
            for: .moderatelyActive,
            isSelected: true
        )

        XCTAssertTrue(label.contains("Moderately Active"))
        XCTAssertTrue(label.contains("selected"))
        XCTAssertTrue(
            label.contains(FormaProductCopy.Onboarding.Flow.Activity.moderatelyActiveExplanationHeadline)
        )
    }

    func testActivityLevelStepDoesNotShowProgressHeaderInShell() {
        XCTAssertFalse(OnboardingStep.activityLevel.showsProgressHeader)
    }

    func testEachActivityOptionCanBeSelected() {
        for level in OnboardingActivityLevelValues.orderedLevels {
            var state = OnboardingFormState()
            OnboardingActivityLevelValues.select(level, in: &state)

            XCTAssertEqual(state.activityLevel, level)
            XCTAssertTrue(state.hasConfirmedActivityLevelSelection)
            XCTAssertTrue(state.canAdvance(from: .activityLevel))
        }
    }

    func testActivitySelectionAutoFillsRhythmWithoutManualEditFlags() {
        var state = OnboardingFormState()
        OnboardingActivityLevelValues.select(.veryActive, in: &state)

        XCTAssertEqual(state.parsedTrainingDays, 5)
        XCTAssertEqual(state.parsedAverageSteps, 10_000)
        XCTAssertFalse(state.hasManuallyEditedTrainingDays)
        XCTAssertFalse(state.hasManuallyEditedAverageSteps)
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
