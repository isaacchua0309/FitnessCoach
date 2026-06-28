//
//  ProfileFormState.swift
//  Fitness Coach
//
//  FitPilot AI — Local form state for profile editing.
//
//  UI input state only. Conversion produces drafts/updates for services.
//

import Foundation

struct ProfileFormState: Equatable {
    var name: String
    var ageText: String
    var sex: Sex
    var heightCmText: String
    var currentWeightKgText: String
    var goalWeightKgText: String
    var estimatedBodyFatPercentageText: String
    var activityLevel: ActivityLevel
    var trainingFrequencyPerWeekText: String
    var averageStepsText: String
    var dietPreference: String
    var unitSystem: UnitSystem

    var calorieTargetText: String
    var proteinTargetText: String
    var carbTargetText: String
    var fatTargetText: String
    var waterTargetMlText: String
    var expectedWeeklyWeightLossKgText: String
    var aggressiveness: CalorieAggressiveness
    var weightLossPaceChoice: WeightLossPaceChoice
    var advancedPaceDraft: WeightLossAdvancedPaceDraft

    init(profile: UserProfile) {
        name = profile.name ?? ""
        ageText = "\(profile.resolvedAge())"
        sex = profile.sex
        heightCmText = Self.formatDouble(profile.heightCm)
        currentWeightKgText = Self.formatDouble(profile.currentWeightKg)
        goalWeightKgText = Self.formatDouble(profile.goalWeightKg)
        estimatedBodyFatPercentageText = profile.estimatedBodyFatPercentage.map { Self.formatDouble($0) } ?? ""
        activityLevel = profile.activityLevel
        trainingFrequencyPerWeekText = "\(profile.trainingFrequencyPerWeek)"
        averageStepsText = "\(profile.averageSteps)"
        dietPreference = profile.dietPreference ?? ""
        unitSystem = profile.unitSystem
        calorieTargetText = "\(profile.targets.calorieTarget)"
        proteinTargetText = Self.formatDouble(profile.targets.proteinTarget)
        carbTargetText = Self.formatDouble(profile.targets.carbTarget)
        fatTargetText = Self.formatDouble(profile.targets.fatTarget)
        waterTargetMlText = "\(profile.targets.waterTargetMl)"
        expectedWeeklyWeightLossKgText = profile.targets.expectedWeeklyWeightLossKg.map { Self.formatDouble($0) } ?? ""
        aggressiveness = profile.targets.aggressiveness
        let inferred = WeightLossPaceChoiceResolver.infer(
            aggressiveness: profile.targets.aggressiveness,
            expectedWeeklyLossKg: profile.targets.expectedWeeklyWeightLossKg,
            weightKg: profile.currentWeightKg,
            goalWeightKg: profile.goalWeightKg
        )
        weightLossPaceChoice = inferred.choice
        advancedPaceDraft = inferred.advancedDraft
    }

    static func defaultDraftValues() -> ProfileFormState {
        ProfileFormState(
            name: "",
            ageText: "24",
            sex: .preferNotToSay,
            heightCmText: "170",
            currentWeightKgText: "70",
            goalWeightKgText: "65",
            estimatedBodyFatPercentageText: "",
            activityLevel: .moderatelyActive,
            trainingFrequencyPerWeekText: "3",
            averageStepsText: "5000",
            dietPreference: "",
            unitSystem: .metric,
            calorieTargetText: "2000",
            proteinTargetText: "140",
            carbTargetText: "200",
            fatTargetText: "56",
            waterTargetMlText: "2450",
            expectedWeeklyWeightLossKgText: "0.5",
            aggressiveness: .moderate,
            weightLossPaceChoice: .moderate,
            advancedPaceDraft: .default
        )
    }

    private init(
        name: String,
        ageText: String,
        sex: Sex,
        heightCmText: String,
        currentWeightKgText: String,
        goalWeightKgText: String,
        estimatedBodyFatPercentageText: String,
        activityLevel: ActivityLevel,
        trainingFrequencyPerWeekText: String,
        averageStepsText: String,
        dietPreference: String,
        unitSystem: UnitSystem,
        calorieTargetText: String,
        proteinTargetText: String,
        carbTargetText: String,
        fatTargetText: String,
        waterTargetMlText: String,
        expectedWeeklyWeightLossKgText: String,
        aggressiveness: CalorieAggressiveness,
        weightLossPaceChoice: WeightLossPaceChoice,
        advancedPaceDraft: WeightLossAdvancedPaceDraft
    ) {
        self.name = name
        self.ageText = ageText
        self.sex = sex
        self.heightCmText = heightCmText
        self.currentWeightKgText = currentWeightKgText
        self.goalWeightKgText = goalWeightKgText
        self.estimatedBodyFatPercentageText = estimatedBodyFatPercentageText
        self.activityLevel = activityLevel
        self.trainingFrequencyPerWeekText = trainingFrequencyPerWeekText
        self.averageStepsText = averageStepsText
        self.dietPreference = dietPreference
        self.unitSystem = unitSystem
        self.calorieTargetText = calorieTargetText
        self.proteinTargetText = proteinTargetText
        self.carbTargetText = carbTargetText
        self.fatTargetText = fatTargetText
        self.waterTargetMlText = waterTargetMlText
        self.expectedWeeklyWeightLossKgText = expectedWeeklyWeightLossKgText
        self.aggressiveness = aggressiveness
        self.weightLossPaceChoice = weightLossPaceChoice
        self.advancedPaceDraft = advancedPaceDraft
    }

    func makeDraft(targets: UserTargets) throws -> UserProfileDraft {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDiet = dietPreference.trimmingCharacters(in: .whitespacesAndNewlines)

        return UserProfileDraft(
            name: trimmedName.isEmpty ? nil : trimmedName,
            age: try parsePositiveInt(ageText, fieldName: "Age"),
            sex: sex,
            heightCm: try parsePositiveDouble(heightCmText, fieldName: "Height"),
            currentWeightKg: try parsePositiveDouble(currentWeightKgText, fieldName: "Baseline weight"),
            goalWeightKg: try parsePositiveDouble(goalWeightKgText, fieldName: "Goal weight"),
            estimatedBodyFatPercentage: try parseOptionalBodyFat(estimatedBodyFatPercentageText),
            activityLevel: activityLevel,
            trainingFrequencyPerWeek: try parseNonNegativeInt(
                trainingFrequencyPerWeekText,
                fieldName: "Training frequency"
            ),
            averageSteps: try parseNonNegativeInt(averageStepsText, fieldName: "Average steps"),
            dietPreference: trimmedDiet.isEmpty ? nil : trimmedDiet,
            unitSystem: unitSystem,
            targets: try makeTargets()
        )
    }

    func makeUpdate() throws -> UserProfileUpdate {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDiet = dietPreference.trimmingCharacters(in: .whitespacesAndNewlines)

        return UserProfileUpdate(
            name: trimmedName.isEmpty ? nil : trimmedName,
            age: try parsePositiveInt(ageText, fieldName: "Age"),
            sex: sex,
            heightCm: try parsePositiveDouble(heightCmText, fieldName: "Height"),
            currentWeightKg: try parsePositiveDouble(currentWeightKgText, fieldName: "Baseline weight"),
            goalWeightKg: try parsePositiveDouble(goalWeightKgText, fieldName: "Goal weight"),
            estimatedBodyFatPercentage: try parseOptionalBodyFat(estimatedBodyFatPercentageText),
            activityLevel: activityLevel,
            trainingFrequencyPerWeek: try parseNonNegativeInt(
                trainingFrequencyPerWeekText,
                fieldName: "Training frequency"
            ),
            averageSteps: try parseNonNegativeInt(averageStepsText, fieldName: "Average steps"),
            dietPreference: trimmedDiet.isEmpty ? nil : trimmedDiet,
            unitSystem: unitSystem,
            targets: try makeTargets()
        )
    }

    func makeCalorieTargetInput() throws -> CalorieTargetInput {
        let pace = try resolvedWeightLossPace()
        return CalorieTargetInput(
            age: try parsePositiveInt(ageText, fieldName: "Age"),
            sex: sex,
            heightCm: try parsePositiveDouble(heightCmText, fieldName: "Height"),
            weightKg: try parsePositiveDouble(currentWeightKgText, fieldName: "Baseline weight"),
            goalWeightKg: try parsePositiveDouble(goalWeightKgText, fieldName: "Goal weight"),
            estimatedBodyFatPercentage: try parseOptionalBodyFat(estimatedBodyFatPercentageText),
            activityLevel: activityLevel,
            trainingFrequencyPerWeek: try parseNonNegativeInt(
                trainingFrequencyPerWeekText,
                fieldName: "Training frequency"
            ),
            averageSteps: try parseNonNegativeInt(averageStepsText, fieldName: "Average steps"),
            aggressiveness: weightLossPaceChoice.legacyAggressiveness,
            weightLossPace: pace
        )
    }

    func resolvedWeightLossPace() throws -> WeightLossPace {
        let weightKg = try parsePositiveDouble(currentWeightKgText, fieldName: "Baseline weight")
        let goalWeightKg = try parsePositiveDouble(goalWeightKgText, fieldName: "Goal weight")
        let isCut = goalWeightKg < weightKg - FormaCalculationConstants.goalDirectionEpsilonKg

        guard isCut else {
            return weightLossPaceChoice.weightLossPace ?? .preset(.moderate)
        }

        return try WeightLossPaceChoiceResolver.resolvedPace(
            choice: weightLossPaceChoice,
            advancedDraft: advancedPaceDraft
        )
    }

    mutating func syncAggressivenessFromPaceChoice() {
        aggressiveness = weightLossPaceChoice.legacyAggressiveness
    }

    private func makeTargets() throws -> UserTargets {
        UserTargets(
            calorieTarget: try parsePositiveInt(calorieTargetText, fieldName: "Calorie target"),
            proteinTarget: try parseNonNegativeDouble(proteinTargetText, fieldName: "Protein target"),
            carbTarget: try parseNonNegativeDouble(carbTargetText, fieldName: "Carb target"),
            fatTarget: try parseNonNegativeDouble(fatTargetText, fieldName: "Fat target"),
            waterTargetMl: try parsePositiveInt(waterTargetMlText, fieldName: "Water target"),
            expectedWeeklyWeightLossKg: try parseOptionalNonNegativeDouble(
                expectedWeeklyWeightLossKgText,
                fieldName: "Expected weekly loss"
            ),
            aggressiveness: aggressiveness
        )
    }

    private func parsePositiveInt(_ text: String, fieldName: String) throws -> Int {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Int(trimmed), value > 0 else {
            throw ProfileFormError.invalid("\(fieldName) must be a positive whole number.")
        }
        return value
    }

    private func parseNonNegativeInt(_ text: String, fieldName: String) throws -> Int {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Int(trimmed), value >= 0 else {
            throw ProfileFormError.invalid("\(fieldName) must be zero or greater.")
        }
        return value
    }

    private func parsePositiveDouble(_ text: String, fieldName: String) throws -> Double {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(trimmed), value > 0 else {
            throw ProfileFormError.invalid("\(fieldName) must be positive.")
        }
        return value
    }

    private func parseNonNegativeDouble(_ text: String, fieldName: String) throws -> Double {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(trimmed), value >= 0 else {
            throw ProfileFormError.invalid("\(fieldName) must be zero or greater.")
        }
        return value
    }

    private func parseOptionalBodyFat(_ text: String) throws -> Double? {
        let normalized = OnboardingFormState.normalizedBodyFatText(text)
        guard !normalized.isEmpty else { return nil }
        guard let value = Double(normalized), (3...70).contains(value) else {
            throw ProfileFormError.invalid(FormaProductCopy.Onboarding.Validation.bodyFatRange)
        }
        return value
    }

    private func parseOptionalNonNegativeDouble(_ text: String, fieldName: String) throws -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let value = Double(trimmed), value >= 0 else {
            throw ProfileFormError.invalid("\(fieldName) must be zero or greater.")
        }
        return value
    }

    private nonisolated static func formatDouble(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value))"
            : "\(value)"
    }

    mutating func applyGeneratedTargets(_ targets: UserTargets) {
        calorieTargetText = "\(targets.calorieTarget)"
        proteinTargetText = Self.formatDouble(targets.proteinTarget)
        carbTargetText = Self.formatDouble(targets.carbTarget)
        fatTargetText = Self.formatDouble(targets.fatTarget)
        waterTargetMlText = "\(targets.waterTargetMl)"
        expectedWeeklyWeightLossKgText = targets.expectedWeeklyWeightLossKg.map { Self.formatDouble($0) } ?? ""
        aggressiveness = targets.aggressiveness
        if weightLossPaceChoice != .advanced {
            weightLossPaceChoice = WeightLossPaceChoice(
                preset: WeightLossPreset(legacy: targets.aggressiveness)
            )
        }
    }
}

enum ProfileFormError: Error, Equatable {
    case invalid(String)

    var message: String {
        switch self {
        case .invalid(let message):
            return message
        }
    }
}
