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

    func testLossGoalPersonalizationSummary() {
        let state = makeFormState(currentKg: 70, goalDeltaKg: -3.5)
        let blueprint = OnboardingPlanBlueprintBuilder.build(from: state, referenceDate: referenceDate)

        XCTAssertEqual(blueprint.headline, "We listened.")
        XCTAssertEqual(
            blueprint.supportingParagraph,
            FormaProductCopy.Onboarding.Flow.Summary.supportingParagraph
        )
        XCTAssertTrue(blueprint.personalizationSummary.contains("Lose 3.5 kg"))
        XCTAssertTrue(blueprint.personalizationSummary.contains("70 kg → 66.5 kg"))
        XCTAssertTrue(blueprint.personalizationSummary.contains("Moderately active"))
        XCTAssertTrue(blueprint.isPersonalized)
        XCTAssertTrue(blueprint.accessibilityLabel.contains("We listened."))
        XCTAssertTrue(blueprint.accessibilityLabel.contains("Your plan:"))
    }

    func testGainGoalPersonalizationSummary() {
        let state = makeFormState(currentKg: 66, goalDeltaKg: 4)
        let blueprint = OnboardingPlanBlueprintBuilder.build(from: state, referenceDate: referenceDate)

        XCTAssertTrue(blueprint.personalizationSummary.contains("Gain 4 kg"))
        XCTAssertTrue(blueprint.personalizationSummary.contains("66 kg → 70 kg"))
    }

    func testMaintainGoalPersonalizationSummary() {
        let state = makeFormState(currentKg: 70, goalDeltaKg: 0)
        let blueprint = OnboardingPlanBlueprintBuilder.build(from: state, referenceDate: referenceDate)

        XCTAssertTrue(blueprint.personalizationSummary.contains("Stay near 70 kg"))
        XCTAssertTrue(blueprint.personalizationSummary.contains("Moderately active"))
        XCTAssertFalse(
            blueprint.personalizationSummary.lowercased().contains("we'll help you stay consistent")
        )
    }

    func testFallbackWhenWeightsMissing() {
        let blueprint = OnboardingPlanBlueprintBuilder.build(
            from: OnboardingFormState(),
            referenceDate: referenceDate
        )

        XCTAssertEqual(
            blueprint.personalizationSummary,
            FormaProductCopy.Onboarding.Flow.Summary.fallbackPersonalizationSummary
        )
        XCTAssertFalse(blueprint.isPersonalized)
    }

    func testImperialFormatting() {
        var state = makeFormState(currentKg: 70, goalDeltaKg: -3.5)
        state.unitSystem = .imperial
        let blueprint = OnboardingPlanBlueprintBuilder.build(from: state, referenceDate: referenceDate)

        XCTAssertTrue(blueprint.personalizationSummary.contains("lb"))
    }

    func testPillarsUsePersonalizationCopy() {
        let blueprint = OnboardingPlanBlueprintBuilder.build(
            from: makeFormState(currentKg: 70, goalDeltaKg: -2),
            referenceDate: referenceDate
        )
        let pillars = FormaProductCopy.Onboarding.Flow.Summary.Pillars.self

        XCTAssertEqual(blueprint.pillars.count, 3)
        XCTAssertEqual(blueprint.pillars.map(\.title), pillars.items.map(\.title))
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

        XCTAssertTrue(blueprint.personalizationSummary.contains("Lose 5 kg"))
        XCTAssertTrue(blueprint.isPersonalized)
    }

    func testReviewStepUsesFixedViewportShell() {
        XCTAssertTrue(OnboardingStep.review.usesFixedViewportShell)
    }

    func testReviewStepHidesDuplicateProgressHeader() {
        XCTAssertFalse(OnboardingStep.review.showsProgressHeader)
    }

    func testMaintainAccessibilityLabelUsesLearnedFraming() {
        let state = makeFormState(currentKg: 70, goalDeltaKg: 0)
        let blueprint = OnboardingPlanBlueprintBuilder.build(from: state, referenceDate: referenceDate)

        XCTAssertTrue(blueprint.accessibilityLabel.contains("We listened."))
        XCTAssertTrue(blueprint.accessibilityLabel.contains("Stay near 70 kilograms"))
        XCTAssertTrue(blueprint.accessibilityLabel.contains("Targets tuned to your body"))
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
            copy.supportingParagraph,
            copy.fallbackPersonalizationSummary,
            copy.Pillars.accessibilityLabel,
            copy.Pillars.items.map(\.title).joined(separator: " "),
            copy.buildPlanCTA
        ]
    }
}
