//
//  OnboardingDraftMigration.swift
//  Fitness Coach
//
//  Forma — Upgrades schema v1 onboarding drafts to the canonical v2 format.
//

import Foundation

enum OnboardingDraftMigration {

    static let legacyDraftVersion = 1

    static func upgrade(from v1: OnboardingDraftV1) -> OnboardingDraft {
        let formState = migrateFormState(from: v1.form, referenceDate: v1.savedAt)
        let flow = OnboardingStep.flow
        let step = OnboardingDraftStepResolver.restoredStep(
            rawValue: v1.currentStepRawValue,
            formState: formState,
            flow: flow
        )

        return OnboardingDraft(
            draftVersion: OnboardingDraft.currentDraftVersion,
            currentStepRawValue: step.rawValue,
            form: OnboardingDraftFormFields(formState: formState),
            generatedPlan: v1.generatedPlan,
            savedAt: v1.savedAt
        )
    }

    static func migrateFormState(
        from legacy: OnboardingDraftV1FormFields,
        referenceDate: Date = Date()
    ) -> OnboardingFormState {
        var state = OnboardingFormState()
        state.name = legacy.name
        state.ageText = legacy.ageText
        if let birthDateISO8601 = legacy.birthDateISO8601 {
            state.birthDate = BirthDatePersistence.decode(birthDateISO8601)
        }
        state.sex = Sex(rawValue: legacy.sexRawValue) ?? .preferNotToSay
        state.heightCmText = legacy.heightCmText
        state.currentWeightKgText = legacy.currentWeightKgText
        state.goalWeightKgText = legacy.goalWeightKgText
        state.activityLevel = ActivityLevel(rawValue: legacy.activityLevelRawValue) ?? .moderatelyActive
        state.trainingFrequencyPerWeekText = legacy.trainingFrequencyPerWeekText
        state.averageStepsText = legacy.averageStepsText
        state.dietPreference = legacy.dietPreference
        state.unitSystem = UnitSystem(rawValue: legacy.unitSystemRawValue) ?? .metric

        if let paceChoice = WeightLossPaceChoice(rawValue: legacy.weightLossPaceChoiceRawValue) {
            state.weightLossPaceChoice = paceChoice
        } else if let aggressiveness = CalorieAggressiveness(rawValue: legacy.aggressivenessRawValue) {
            let weightKg = state.parsedCurrentWeightKg ?? OnboardingPickerDefaults.defaultWeightKg
            let goalWeightKg = state.parsedGoalWeightKg ?? weightKg
            state.weightLossPaceChoice = WeightLossPaceChoiceResolver.infer(
                aggressiveness: aggressiveness,
                expectedWeeklyLossKg: nil,
                weightKg: weightKg,
                goalWeightKg: goalWeightKg
            ).choice
        }

        state.advancedPaceDraft = WeightLossAdvancedPaceDraft(
            period: WeightLossAdvancedPaceDraft.Period(rawValue: legacy.advancedPacePeriodRawValue) ?? .weekly,
            amountText: legacy.advancedPaceAmountText
        )
        state.syncAggressivenessFromPaceChoice()
        state.selectedMotivations = OnboardingMotivation.fromStoredValues(legacy.selectedMotivationRawValues)
        state.loggingPreferences = OnboardingLoggingPreference.fromStoredValues(
            legacy.selectedLoggingPreferenceRawValues
        )
        state.reconcileBirthDateAfterRestore(referenceDate: referenceDate)
        state.reconcileTrainingRhythmAfterRestore()
        if !legacy.activityLevelRawValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            state.hasConfirmedActivityLevelSelection = true
        }
        state.syncAgeTextFromBirthDate(referenceDate: referenceDate)
        return state
    }
}

struct OnboardingDraftV1: Codable, Equatable, Sendable {
    var draftVersion: Int
    var currentStepRawValue: Int
    var form: OnboardingDraftV1FormFields
    var generatedPlan: OnboardingDraftGeneratedPlan?
    var savedAt: Date
}

struct OnboardingDraftV1FormFields: Codable, Equatable, Sendable {
    var name: String
    var ageText: String
    var birthDateISO8601: String?
    var sexRawValue: String
    var heightCmText: String
    var currentWeightKgText: String
    var goalWeightKgText: String
    var estimatedBodyFatPercentageText: String
    var activityLevelRawValue: String
    var trainingFrequencyPerWeekText: String
    var averageStepsText: String
    var dietPreference: String
    var unitSystemRawValue: String
    var aggressivenessRawValue: String
    var weightLossPaceChoiceRawValue: String
    var advancedPacePeriodRawValue: String
    var advancedPaceAmountText: String
    var selectedMotivationRawValues: [String] = []
    var selectedLoggingPreferenceRawValues: [String] = []
}
