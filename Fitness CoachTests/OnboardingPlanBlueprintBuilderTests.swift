//
//  OnboardingPlanBlueprintBuilderTests.swift
//  Fitness CoachTests
//
//  Forma — plan blueprint builder tests for onboarding review.
//

import XCTest
@testable import Fitness_Coach

final class OnboardingPlanBlueprintBuilderTests: XCTestCase {

    private let calendar = Calendar(identifier: .gregorian)
    private let referenceDate = FormaCalculationTestFixtures.referenceDate

    private let forbiddenCopyFragments = [
        "dynamic calor",
        "body fat",
        "gym session",
        "manual steps",
        "training days",
        "Almost ready",
        "review details",
        "built from your answers",
        "we'll help you stay consistent",
        "one last check",
        "edit your answers"
    ]

    func testMaintainGoalCard() {
        let state = makeFormState(currentKg: 70, goalDeltaKg: 0)
        let blueprint = OnboardingPlanBlueprintBuilder.build(from: state, referenceDate: referenceDate)
        let goalCard = FormaProductCopy.Onboarding.Flow.Summary.GoalCard.self

        XCTAssertEqual(blueprint.heroTitle, "Your plan blueprint")
        XCTAssertEqual(blueprint.illustrationStyle, .maintain)
        XCTAssertEqual(blueprint.goalCard.directionLabel, goalCard.maintainDirection)
        XCTAssertEqual(blueprint.goalCard.targetWeight, "70 kg")
        XCTAssertEqual(blueprint.goalCard.paceValue, goalCard.maintainPace)
        XCTAssertEqual(blueprint.goalCard.timelineValue, goalCard.maintainTimeline)
        XCTAssertTrue(blueprint.isPersonalized)
    }

    func testLossGoalCardIncludesPaceAndTimeline() {
        let state = makeFormState(currentKg: 70, goalDeltaKg: -3.5)
        let blueprint = OnboardingPlanBlueprintBuilder.build(from: state, referenceDate: referenceDate)

        XCTAssertEqual(blueprint.illustrationStyle, .loss)
        XCTAssertEqual(blueprint.goalCard.directionLabel, "Lose toward")
        XCTAssertEqual(blueprint.goalCard.targetWeight, "66.5 kg")
        XCTAssertTrue(blueprint.goalCard.paceValue.contains("kg"))
        XCTAssertTrue(blueprint.goalCard.timelineValue.contains("weeks"))
    }

    func testGainGoalCard() {
        let state = makeFormState(currentKg: 66, goalDeltaKg: 4)
        let blueprint = OnboardingPlanBlueprintBuilder.build(from: state, referenceDate: referenceDate)
        let goalCard = FormaProductCopy.Onboarding.Flow.Summary.GoalCard.self

        XCTAssertEqual(blueprint.illustrationStyle, .gain)
        XCTAssertEqual(blueprint.goalCard.directionLabel, goalCard.gainDirection)
        XCTAssertEqual(blueprint.goalCard.targetWeight, "70 kg")
        XCTAssertEqual(blueprint.goalCard.paceValue, goalCard.gainPace)
        XCTAssertEqual(blueprint.goalCard.timelineValue, goalCard.gainTimeline)
    }

    func testFallbackWhenWeightsMissing() {
        let blueprint = OnboardingPlanBlueprintBuilder.build(
            from: OnboardingFormState(),
            referenceDate: referenceDate
        )
        let goalCard = FormaProductCopy.Onboarding.Flow.Summary.GoalCard.self

        XCTAssertEqual(blueprint.illustrationStyle, .fallback)
        XCTAssertEqual(blueprint.goalCard.targetWeight, goalCard.fallbackTarget)
        XCTAssertFalse(blueprint.isPersonalized)
    }

    func testImperialFormatting() {
        var state = makeFormState(currentKg: 70, goalDeltaKg: -3.5)
        state.unitSystem = .imperial
        let blueprint = OnboardingPlanBlueprintBuilder.build(from: state, referenceDate: referenceDate)

        XCTAssertTrue(blueprint.goalCard.targetWeight.contains("lb"))
    }

    func testPremiumFeaturesUseBlueprintCopy() {
        let blueprint = OnboardingPlanBlueprintBuilder.build(
            from: makeFormState(currentKg: 70, goalDeltaKg: -2),
            referenceDate: referenceDate
        )
        let features = FormaProductCopy.Onboarding.Flow.Summary.PremiumFeatures.self

        XCTAssertEqual(blueprint.premiumFeatures.count, 3)
        XCTAssertEqual(blueprint.premiumFeatures.map(\.title), ["Nutrition", "Activity", "Progress"])
    }

    func testGeneratedSignalsIncludeSixInputs() {
        let blueprint = OnboardingPlanBlueprintBuilder.build(
            from: makeFormState(currentKg: 70, goalDeltaKg: -2),
            referenceDate: referenceDate
        )
        let copy = FormaProductCopy.Onboarding.Flow.Summary.GeneratedSummary.self

        XCTAssertEqual(blueprint.generatedSignals.count, 6)
        XCTAssertEqual(blueprint.generatedSignals.map(\.id), [
            "activity", "currentWeight", "goal", "nutrition", "lifestyle", "training"
        ])
        XCTAssertTrue(blueprint.generatedSignals.allSatisfy(\.isIncluded))
        XCTAssertEqual(blueprint.generatedSignals[0].label, copy.activityLevel)
        XCTAssertEqual(blueprint.generatedSignals[1].label, copy.currentWeight)
        XCTAssertEqual(blueprint.generatedSignals[3].label, copy.nutritionTargets)
        XCTAssertEqual(blueprint.generatedSignals[5].label, copy.trainingRhythm)
    }

    func testBlueprintCopyAvoidsUnsafeClaims() {
        let samples = allBlueprintCopySamples()
        for sample in samples {
            let lowered = sample.lowercased()
            for fragment in forbiddenCopyFragments {
                XCTAssertFalse(
                    lowered.contains(fragment),
                    "Unexpected fragment \"\(fragment)\" in: \(sample)"
                )
            }
        }
    }

    func testRestoredDraftProducesPersonalizedBlueprint() throws {
        let defaults = UserDefaults(suiteName: "OnboardingPlanBlueprintBuilderTests.\(UUID().uuidString)")!
        defer { defaults.removePersistentDomain(forName: defaults.description) }

        var formState = try validFormState()
        OnboardingTargetWeightValues.setGoalFromDeltaKg(-5, in: &formState)

        let store = OnboardingDraftStore(userDefaults: defaults)
        store.saveDraft(OnboardingDraft(formState: formState, step: .review))
        let restored = try XCTUnwrap(store.loadDraft()?.makeFormState())
        let blueprint = OnboardingPlanBlueprintBuilder.build(
            from: restored,
            referenceDate: referenceDate
        )

        XCTAssertEqual(blueprint.goalCard.targetWeight, "65 kg")
        XCTAssertTrue(blueprint.isPersonalized)
    }

    func testReviewStepUsesFixedViewportShell() {
        XCTAssertTrue(OnboardingStep.review.usesFixedViewportShell)
    }

    func testReviewStepHidesDuplicateProgressHeader() {
        XCTAssertFalse(OnboardingStep.review.showsProgressHeader)
    }

    func testAccessibilityLabelIncludesGoalAndFeatures() {
        let state = makeFormState(currentKg: 70, goalDeltaKg: 0)
        let blueprint = OnboardingPlanBlueprintBuilder.build(from: state, referenceDate: referenceDate)

        XCTAssertTrue(blueprint.accessibilityLabel.contains("Your plan blueprint"))
        XCTAssertTrue(blueprint.accessibilityLabel.contains("Maintain"))
        XCTAssertTrue(blueprint.accessibilityLabel.contains("Built using"))
        XCTAssertTrue(blueprint.accessibilityLabel.contains("Nutrition"))
    }

    // MARK: - Helpers

    private func makeFormState(currentKg: Double, goalDeltaKg: Double) -> OnboardingFormState {
        var state = OnboardingFormState()
        OnboardingHeightWeightValues.applyDefaultsIfNeeded(to: &state)
        OnboardingHeightWeightValues.setWeightKg(currentKg, in: &state)
        OnboardingTargetWeightValues.setGoalFromDeltaKg(goalDeltaKg, in: &state)
        state.sex = .female
        OnboardingActivityLevelValues.select(.moderatelyActive, in: &state)
        OnboardingBirthdayValues.applyDefaultsIfNeeded(to: &state)
        return state
    }

    private func validFormState() throws -> OnboardingFormState {
        var state = OnboardingFormState()
        OnboardingHeightWeightValues.applyDefaultsIfNeeded(to: &state)
        OnboardingTargetWeightValues.applyDefaultsIfNeeded(to: &state)
        state.sex = .female
        OnboardingActivityLevelValues.select(.moderatelyActive, in: &state)
        let birthDate = calendar.date(from: DateComponents(year: 1992, month: 11, day: 8))!
        state.birthDate = birthDate
        return state
    }

    private func allBlueprintCopySamples() -> [String] {
        let copy = FormaProductCopy.Onboarding.Flow.Summary.self
        return [
            copy.title,
            copy.buildPlanCTA,
            copy.buildPlanAnticipationHeadline,
            copy.buildPlanAnticipationSubline,
            copy.buildPlanAnticipationAccessibilityLabel,
            copy.GoalCard.maintainTimeline,
            copy.GoalCard.maintainPace,
            copy.GoalCard.gainTimeline,
            copy.PremiumFeatures.accessibilityLabel,
            copy.PremiumFeatures.items.map(\.title).joined(separator: " "),
            copy.GeneratedSummary.title,
            copy.GeneratedSummary.activityLevel,
            copy.GeneratedSummary.currentWeight,
            copy.GeneratedSummary.goal,
            copy.GeneratedSummary.nutritionTargets,
            copy.GeneratedSummary.lifestyle,
            copy.GeneratedSummary.trainingRhythm,
            copy.GeneratedSummary.nutritionDetail,
            copy.GeneratedSummary.accessibilityLabel,
        ]
    }
}
