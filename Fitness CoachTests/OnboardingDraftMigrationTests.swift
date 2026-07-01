//
//  OnboardingDraftMigrationTests.swift
//  Fitness CoachTests
//
//  Forma — Legacy draft schema migration and step routing tests.
//

import XCTest
@testable import Fitness_Coach

final class OnboardingDraftMigrationTests: XCTestCase {

    private let calendar = Calendar(identifier: .gregorian)
    private let referenceDate = FormaCalculationTestFixtures.referenceDate

    // MARK: - Legacy step routing

    func testLegacyBodyRoutesToHeightWeightWhenMeasurementsMissing() {
        let restored = OnboardingDraftStepResolver.restoredStep(
            rawValue: OnboardingLegacyPersistedStep.body.rawValue,
            formState: OnboardingFormState(),
            flow: OnboardingStep.flow
        )
        XCTAssertEqual(restored, .heightWeight)
    }

    func testLegacyBodyRoutesToBirthdayWhenMeasurementsValidButBirthDateMissing() {
        var formState = OnboardingFormState()
        OnboardingHeightWeightValues.applyDefaultsIfNeeded(to: &formState)

        let restored = OnboardingDraftStepResolver.restoredStep(
            rawValue: OnboardingLegacyPersistedStep.body.rawValue,
            formState: formState,
            flow: OnboardingStep.flow
        )
        XCTAssertEqual(restored, .birthday)
    }

    func testLegacyBodyRoutesToTargetWeightWhenBodyStageComplete() throws {
        var formState = try validFormState()

        let restored = OnboardingDraftStepResolver.restoredStep(
            rawValue: OnboardingLegacyPersistedStep.body.rawValue,
            formState: formState,
            flow: OnboardingStep.flow
        )
        XCTAssertEqual(restored, .activityLevel)
    }

    func testLegacyGoalRoutesToTargetWeightWhenInvalid() {
        var formState = OnboardingFormState()
        OnboardingHeightWeightValues.applyDefaultsIfNeeded(to: &formState)

        let restored = OnboardingDraftStepResolver.restoredStep(
            rawValue: OnboardingLegacyPersistedStep.goal.rawValue,
            formState: formState,
            flow: OnboardingStep.flow
        )
        XCTAssertEqual(restored, .targetWeight)
    }

    func testLegacyActivityRoutesToActivityLevel() throws {
        let formState = try validFormState()

        let restored = OnboardingDraftStepResolver.restoredStep(
            rawValue: OnboardingLegacyPersistedStep.activity.rawValue,
            formState: formState,
            flow: OnboardingStep.flow
        )
        XCTAssertEqual(restored, .activityLevel)
    }

    func testLegacyPreferencesRoutesToReviewWhenRequiredFieldsValid() throws {
        let formState = try validFormState()

        let restored = OnboardingDraftStepResolver.restoredStep(
            rawValue: OnboardingLegacyPersistedStep.preferences.rawValue,
            formState: formState,
            flow: OnboardingStep.flow
        )
        XCTAssertEqual(restored, .review)
    }

    func testLegacyPreferencesRoutesToMissingRequiredStepWhenInvalid() {
        var formState = OnboardingFormState()
        OnboardingHeightWeightValues.applyDefaultsIfNeeded(to: &formState)

        let restored = OnboardingDraftStepResolver.restoredStep(
            rawValue: OnboardingLegacyPersistedStep.preferences.rawValue,
            formState: formState,
            flow: OnboardingStep.flow
        )
        XCTAssertEqual(restored, .targetWeight)
    }

    func testLegacyGeneratingPlanRoutesToReview() {
        let restored = OnboardingDraftStepResolver.restoredStep(
            rawValue: OnboardingLegacyPersistedStep.generatingPlan.rawValue,
            formState: OnboardingFormState(),
            flow: OnboardingStep.flow
        )
        XCTAssertEqual(restored, .review)
    }

    func testCanonicalGeneratingPlanStoredValueRoutesToReview() {
        let restored = OnboardingDraftStepResolver.restoredStep(
            rawValue: OnboardingStep.generatingPlan.rawValue,
            formState: OnboardingFormState(),
            flow: OnboardingStep.flow
        )
        XCTAssertEqual(restored, .review)
    }

    func testLegacyGoalRoutesToWeightLossPaceForCutGoal() throws {
        var formState = try validFormState()
        OnboardingTargetWeightValues.setGoalFromDeltaKg(-4, in: &formState)

        let restored = OnboardingDraftStepResolver.restoredStep(
            rawValue: OnboardingLegacyPersistedStep.goal.rawValue,
            formState: formState,
            flow: OnboardingStep.flow
        )

        XCTAssertEqual(restored, .weightLossPace)
    }

    func testLegacyGoalRoutesToTargetEncouragementForMaintainGoal() throws {
        var formState = try validFormState()
        OnboardingTargetWeightValues.applyDefaultsIfNeeded(to: &formState)

        let restored = OnboardingDraftStepResolver.restoredStep(
            rawValue: OnboardingLegacyPersistedStep.goal.rawValue,
            formState: formState,
            flow: OnboardingStep.flow
        )

        XCTAssertEqual(restored, .targetEncouragement)
    }

    func testV1MigrationInfersPaceFromAggressivenessWhenPaceChoiceMissing() {
        let legacy = OnboardingDraftV1(
            draftVersion: 1,
            currentStepRawValue: OnboardingLegacyPersistedStep.goal.rawValue,
            form: OnboardingDraftV1FormFields(
                name: "",
                ageText: "30",
                birthDateISO8601: nil,
                sexRawValue: Sex.female.rawValue,
                heightCmText: "170",
                currentWeightKgText: "72",
                goalWeightKgText: "65",
                estimatedBodyFatPercentageText: "",
                activityLevelRawValue: ActivityLevel.moderatelyActive.rawValue,
                trainingFrequencyPerWeekText: "3",
                averageStepsText: "5000",
                dietPreference: "",
                unitSystemRawValue: UnitSystem.metric.rawValue,
                aggressivenessRawValue: CalorieAggressiveness.aggressive.rawValue,
                weightLossPaceChoiceRawValue: "",
                advancedPacePeriodRawValue: "",
                advancedPaceAmountText: ""
            ),
            generatedPlan: nil,
            savedAt: referenceDate
        )

        let restored = OnboardingDraftMigration.upgrade(from: legacy).makeFormState()

        XCTAssertEqual(restored.weightLossPaceChoice, .aggressive)
        XCTAssertEqual(restored.aggressiveness, .aggressive)
    }

    // MARK: - Schema migration

    func testLegacyAgeTextDraftSynthesizesBirthDate() throws {
        let legacy = OnboardingDraftV1(
            draftVersion: 1,
            currentStepRawValue: OnboardingLegacyPersistedStep.body.rawValue,
            form: OnboardingDraftV1FormFields(
                name: "",
                ageText: "30",
                birthDateISO8601: nil,
                sexRawValue: Sex.female.rawValue,
                heightCmText: "170",
                currentWeightKgText: "72",
                goalWeightKgText: "65",
                estimatedBodyFatPercentageText: "24",
                activityLevelRawValue: ActivityLevel.moderatelyActive.rawValue,
                trainingFrequencyPerWeekText: "3",
                averageStepsText: "5000",
                dietPreference: "",
                unitSystemRawValue: UnitSystem.metric.rawValue,
                aggressivenessRawValue: CalorieAggressiveness.moderate.rawValue,
                weightLossPaceChoiceRawValue: WeightLossPaceChoice.moderate.rawValue,
                advancedPacePeriodRawValue: WeightLossAdvancedPaceDraft.default.period.rawValue,
                advancedPaceAmountText: ""
            ),
            generatedPlan: nil,
            savedAt: referenceDate
        )

        let migrated = OnboardingDraftMigration.upgrade(from: legacy)
        let restored = migrated.makeFormState()

        XCTAssertEqual(migrated.draftVersion, 2)
        XCTAssertNotNil(restored.birthDate)
        XCTAssertEqual(
            try restored.resolvedAge(referenceDate: referenceDate),
            30
        )
        XCTAssertTrue(restored.estimatedBodyFatPercentageText.isEmpty)
    }

    func testLegacyDraftAutoUpgradesOnLoad() throws {
        let legacy = OnboardingDraftV1(
            draftVersion: 1,
            currentStepRawValue: OnboardingLegacyPersistedStep.motivation.rawValue,
            form: OnboardingDraftV1FormFields(
                name: "Alex",
                ageText: "",
                birthDateISO8601: BirthDatePersistence.encode(
                    try XCTUnwrap(calendar.date(from: DateComponents(year: 1992, month: 3, day: 4)))
                ),
                sexRawValue: Sex.female.rawValue,
                heightCmText: "168",
                currentWeightKgText: "72",
                goalWeightKgText: "65",
                estimatedBodyFatPercentageText: "",
                activityLevelRawValue: ActivityLevel.moderatelyActive.rawValue,
                trainingFrequencyPerWeekText: "3",
                averageStepsText: "5000",
                dietPreference: "",
                unitSystemRawValue: UnitSystem.metric.rawValue,
                aggressivenessRawValue: CalorieAggressiveness.moderate.rawValue,
                weightLossPaceChoiceRawValue: WeightLossPaceChoice.moderate.rawValue,
                advancedPacePeriodRawValue: WeightLossAdvancedPaceDraft.default.period.rawValue,
                advancedPaceAmountText: "",
                selectedMotivationRawValues: ["health"],
                selectedLoggingPreferenceRawValues: ["quickTaps"]
            ),
            generatedPlan: nil,
            savedAt: referenceDate
        )

        let defaults = UserDefaults(suiteName: "OnboardingDraftMigrationTests.\(UUID().uuidString)")!
        defer { defaults.removePersistentDomain(forName: defaults.description) }

        let encoder = JSONEncoder()
        let data = try encoder.encode(legacy)
        defaults.set(data, forKey: OnboardingDraftStore.userDefaultsKey)

        let store = OnboardingDraftStore(userDefaults: defaults)
        let loaded = try XCTUnwrap(store.loadDraft())

        XCTAssertEqual(loaded.draftVersion, 2)
        XCTAssertEqual(loaded.step, .review)
        XCTAssertEqual(loaded.makeFormState().selectedMotivations, [.health])
        XCTAssertEqual(loaded.makeFormState().loggingPreferences, [.quickTaps])

        let reloaded = try XCTUnwrap(store.loadDraft())
        XCTAssertEqual(reloaded.draftVersion, 2)
        XCTAssertEqual(reloaded.step, .review)
    }

    func testLegacyRawValuesRemainStableForMigration() {
        XCTAssertEqual(OnboardingLegacyPersistedStep(rawValue: 1), .body)
        XCTAssertEqual(OnboardingLegacyPersistedStep(rawValue: 12), .summary)
        XCTAssertEqual(OnboardingLegacyPersistedStep(rawValue: 15), .savePlan)
        XCTAssertNil(OnboardingLegacyPersistedStep(rawValue: 999))
    }

    // MARK: - Helpers

    private func validFormState() throws -> OnboardingFormState {
        var state = OnboardingFormState()
        OnboardingHeightWeightValues.applyDefaultsIfNeeded(to: &state)
        OnboardingTargetWeightValues.applyDefaultsIfNeeded(to: &state)
        OnboardingBirthdayValues.applyDefaultsIfNeeded(to: &state)
        state.sex = .female
        OnboardingActivityLevelValues.select(.moderatelyActive, in: &state)
        state.selectPaceChoice(.moderate)
        return state
    }
}
