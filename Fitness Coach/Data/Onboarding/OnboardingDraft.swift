//
//  OnboardingDraft.swift
//  Fitness Coach
//
//  Forma — Codable onboarding wizard snapshot for UserDefaults persistence.
//

import Foundation

struct OnboardingDraft: Codable, Equatable, Sendable {

    static let currentDraftVersion = 1

    var draftVersion: Int
    var currentStepRawValue: Int
    var form: OnboardingDraftFormFields
    var generatedPlan: OnboardingDraftGeneratedPlan?
    var savedAt: Date

    init(
        draftVersion: Int = Self.currentDraftVersion,
        currentStepRawValue: Int,
        form: OnboardingDraftFormFields,
        generatedPlan: OnboardingDraftGeneratedPlan? = nil,
        savedAt: Date = Date()
    ) {
        self.draftVersion = draftVersion
        self.currentStepRawValue = currentStepRawValue
        self.form = form
        self.generatedPlan = generatedPlan
        self.savedAt = savedAt
    }

    init(
        formState: OnboardingFormState,
        currentStep: OnboardingStep,
        generatedPlan: CalorieTargetResult? = nil,
        savedAt: Date = Date()
    ) {
        draftVersion = Self.currentDraftVersion
        currentStepRawValue = currentStep.rawValue
        form = OnboardingDraftFormFields(formState: formState)
        self.generatedPlan = generatedPlan.map(OnboardingDraftGeneratedPlan.init(result:))
        self.savedAt = savedAt
    }

    var currentStep: OnboardingStep? {
        OnboardingStep(rawValue: currentStepRawValue)
    }

    func makeFormState() -> OnboardingFormState {
        form.makeFormState()
    }

    func makeGeneratedPlan() -> CalorieTargetResult? {
        generatedPlan?.makeCalorieTargetResult()
    }
}

struct OnboardingDraftFormFields: Codable, Equatable, Sendable {
    var name: String
    var ageText: String
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

    init(formState: OnboardingFormState) {
        name = formState.name
        ageText = formState.ageText
        sexRawValue = formState.sex.rawValue
        heightCmText = formState.heightCmText
        currentWeightKgText = formState.currentWeightKgText
        goalWeightKgText = formState.goalWeightKgText
        estimatedBodyFatPercentageText = formState.estimatedBodyFatPercentageText
        activityLevelRawValue = formState.activityLevel.rawValue
        trainingFrequencyPerWeekText = formState.trainingFrequencyPerWeekText
        averageStepsText = formState.averageStepsText
        dietPreference = formState.dietPreference
        unitSystemRawValue = formState.unitSystem.rawValue
        aggressivenessRawValue = formState.aggressiveness.rawValue
        weightLossPaceChoiceRawValue = formState.weightLossPaceChoice.rawValue
        advancedPacePeriodRawValue = formState.advancedPaceDraft.period.rawValue
        advancedPaceAmountText = formState.advancedPaceDraft.amountText
        selectedMotivationRawValues = formState.selectedMotivations.map(\.rawValue).sorted()
        selectedLoggingPreferenceRawValues = formState.loggingPreferences.map(\.rawValue).sorted()
    }

    func makeFormState() -> OnboardingFormState {
        var state = OnboardingFormState()
        state.name = name
        state.ageText = ageText
        state.sex = Sex(rawValue: sexRawValue) ?? .preferNotToSay
        state.heightCmText = heightCmText
        state.currentWeightKgText = currentWeightKgText
        state.goalWeightKgText = goalWeightKgText
        state.estimatedBodyFatPercentageText = estimatedBodyFatPercentageText
        state.activityLevel = ActivityLevel(rawValue: activityLevelRawValue) ?? .moderatelyActive
        state.trainingFrequencyPerWeekText = trainingFrequencyPerWeekText
        state.averageStepsText = averageStepsText
        state.dietPreference = dietPreference
        state.unitSystem = UnitSystem(rawValue: unitSystemRawValue) ?? .metric
        state.aggressiveness = CalorieAggressiveness(rawValue: aggressivenessRawValue) ?? .moderate
        if let paceChoice = WeightLossPaceChoice(rawValue: weightLossPaceChoiceRawValue) {
            state.weightLossPaceChoice = paceChoice
        }
        state.advancedPaceDraft = WeightLossAdvancedPaceDraft(
            period: WeightLossAdvancedPaceDraft.Period(rawValue: advancedPacePeriodRawValue) ?? .weekly,
            amountText: advancedPaceAmountText
        )
        state.syncAggressivenessFromPaceChoice()
        state.selectedMotivations = OnboardingMotivation.fromStoredValues(selectedMotivationRawValues)
        state.loggingPreferences = OnboardingLoggingPreference.fromStoredValues(selectedLoggingPreferenceRawValues)
        return state
    }
}

struct OnboardingDraftGeneratedPlan: Codable, Equatable, Sendable {
    var estimatedBMR: Int
    var estimatedTDEE: Int
    var estimatedDailyDeficit: Int
    var isAggressive: Bool
    var warning: String?
    var targets: UserTargets

    init(result: CalorieTargetResult) {
        estimatedBMR = result.estimatedBMR
        estimatedTDEE = result.estimatedTDEE
        estimatedDailyDeficit = result.estimatedDailyDeficit
        isAggressive = result.isAggressive
        warning = result.warning
        targets = result.targets
    }

    func makeCalorieTargetResult() -> CalorieTargetResult {
        CalorieTargetResult(
            estimatedBMR: estimatedBMR,
            estimatedTDEE: estimatedTDEE,
            targets: targets,
            estimatedDailyDeficit: estimatedDailyDeficit,
            isAggressive: isAggressive,
            warning: warning
        )
    }
}
