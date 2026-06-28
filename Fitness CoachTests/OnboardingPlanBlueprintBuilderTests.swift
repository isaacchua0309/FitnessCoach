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
        "Almost ready"
    ]

    func testLossGoalCopy() {
        let state = makeFormState(currentKg: 70, goalDeltaKg: -3.5)
        let blueprint = OnboardingPlanBlueprintBuilder.build(from: state, referenceDate: referenceDate)

        XCTAssertEqual(blueprint.screenTitle, FormaProductCopy.Onboarding.Flow.Summary.title)
        XCTAssertEqual(blueprint.goalHero, "Lose 3.5 kg")
        XCTAssertEqual(blueprint.goalSubtitle, "From 70 kg to 66.5 kg")
        XCTAssertEqual(blueprint.insight, FormaProductCopy.Onboarding.Flow.Summary.Insight.loss)
        XCTAssertTrue(blueprint.isPersonalized)
        XCTAssertTrue(blueprint.accessibilityLabel.contains("steady target") == false)
        XCTAssertTrue(blueprint.accessibilityLabel.contains("Your plan blueprint is ready"))
    }

    func testGainGoalCopy() {
        let state = makeFormState(currentKg: 66, goalDeltaKg: 4)
        let blueprint = OnboardingPlanBlueprintBuilder.build(from: state, referenceDate: referenceDate)

        XCTAssertEqual(blueprint.goalHero, "Gain 4 kg")
        XCTAssertEqual(blueprint.goalSubtitle, "From 66 kg to 70 kg")
        XCTAssertEqual(blueprint.insight, FormaProductCopy.Onboarding.Flow.Summary.Insight.gain)
    }

    func testMaintainGoalCopy() {
        let state = makeFormState(currentKg: 70, goalDeltaKg: 0)
        let blueprint = OnboardingPlanBlueprintBuilder.build(from: state, referenceDate: referenceDate)

        XCTAssertEqual(blueprint.goalHero, "Maintain around 70 kg")
        XCTAssertEqual(
            blueprint.goalSubtitle,
            FormaProductCopy.Onboarding.Flow.Summary.maintainGoalSubtitle
        )
        XCTAssertEqual(blueprint.insight, FormaProductCopy.Onboarding.Flow.Summary.Insight.maintain)
    }

    func testFallbackWhenWeightsMissing() {
        let blueprint = OnboardingPlanBlueprintBuilder.build(
            from: OnboardingFormState(),
            referenceDate: referenceDate
        )

        XCTAssertEqual(blueprint.goalHero, FormaProductCopy.Onboarding.Flow.Summary.goalFallbackHero)
        XCTAssertFalse(blueprint.isPersonalized)
        XCTAssertEqual(blueprint.insight, FormaProductCopy.Onboarding.Flow.Summary.Insight.fallback)
    }

    func testImperialFormatting() {
        var state = makeFormState(currentKg: 70, goalDeltaKg: -3.5)
        state.unitSystem = .imperial
        let blueprint = OnboardingPlanBlueprintBuilder.build(from: state, referenceDate: referenceDate)

        XCTAssertTrue(blueprint.goalHero.contains("lb"))
        XCTAssertTrue(blueprint.goalSubtitle.contains("lb"))
    }

    func testBasisItemsCoverPlanInputs() {
        let blueprint = OnboardingPlanBlueprintBuilder.build(
            from: makeFormState(currentKg: 70, goalDeltaKg: -2),
            referenceDate: referenceDate
        )
        let basis = FormaProductCopy.Onboarding.Flow.Summary.Basis.self

        XCTAssertEqual(blueprint.basisItems.count, 5)
        XCTAssertEqual(blueprint.basisItems.map(\.title), [
            basis.bodyMeasurements,
            basis.age,
            basis.sex,
            basis.activity,
            basis.targetWeight
        ])
    }

    func testDetailRowsUseBirthdayDerivedAge() throws {
        var state = try validFormState()
        state.ageText = "99"

        let blueprint = OnboardingPlanBlueprintBuilder.build(from: state, referenceDate: referenceDate)
        let ageRow = try XCTUnwrap(blueprint.detailRows.first { $0.id == "age" })
        let expectedAge = BirthDateAgeResolver.age(
            from: try XCTUnwrap(state.birthDate),
            referenceDate: referenceDate,
            calendar: calendar
        )

        XCTAssertEqual(ageRow.value, String(expectedAge))
        XCTAssertNotEqual(ageRow.value, "99")
    }

    func testDetailRowsExcludeBodyFatAndManualCollection() throws {
        let state = try validFormState()
        let blueprint = OnboardingPlanBlueprintBuilder.build(from: state, referenceDate: referenceDate)
        let joined = blueprint.detailRows.map { "\($0.title) \($0.value)" }.joined(separator: " ").lowercased()

        XCTAssertFalse(joined.contains("body fat"))
        XCTAssertFalse(joined.contains("steps"))
        XCTAssertFalse(joined.contains("gym"))
        XCTAssertEqual(blueprint.detailRows.count, 6)
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
        OnboardingTargetWeightValues.setGoalFromLossKg(5, in: &formState)

        let store = OnboardingDraftStore(userDefaults: defaults)
        store.saveDraft(OnboardingDraft(formState: formState, step: .review))
        let restored = try XCTUnwrap(store.loadDraft()?.makeFormState())
        let blueprint = OnboardingPlanBlueprintBuilder.build(
            from: restored,
            referenceDate: referenceDate
        )

        XCTAssertEqual(blueprint.goalHero, "Lose 5 kg")
        XCTAssertTrue(blueprint.isPersonalized)
    }

    func testReviewStepHidesDuplicateProgressHeader() {
        XCTAssertFalse(OnboardingStep.review.showsProgressHeader)
    }

    // MARK: - Helpers

    private func makeFormState(currentKg: Double, goalDeltaKg: Double) -> OnboardingFormState {
        var state = OnboardingFormState()
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
            copy.subtitle,
            copy.goalFallbackHero,
            copy.goalFallbackSubtitle,
            copy.maintainGoalSubtitle,
            copy.Insight.loss,
            copy.Insight.gain,
            copy.Insight.maintain,
            copy.Insight.fallback,
            copy.Basis.title,
            copy.Basis.bodyMeasurements,
            copy.Basis.age,
            copy.Basis.sex,
            copy.Basis.activity,
            copy.Basis.targetWeight,
            copy.Details.title
        ]
    }
}
