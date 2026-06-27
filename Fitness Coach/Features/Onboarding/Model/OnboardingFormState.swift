//
//  OnboardingFormState.swift
//  Fitness Coach
//
//  FitPilot AI — Local form state for first-run onboarding.
//
//  UI input state only. Conversion produces drafts for services.
//

import Foundation

struct OnboardingFormState: Equatable {
    var name: String = ""
    var ageText: String = ""
    var sex: Sex = .preferNotToSay
    var heightCmText: String = ""
    var currentWeightKgText: String = ""
    var goalWeightKgText: String = ""
    var estimatedBodyFatPercentageText: String = ""
    var activityLevel: ActivityLevel = .moderatelyActive
    var trainingFrequencyPerWeekText: String = "3"
    var averageStepsText: String = "5000"
    var dietPreference: String = ""
    var unitSystem: UnitSystem = .metric

    /// Legacy field kept for target compatibility; synced from `weightLossPaceChoice`.
    var aggressiveness: CalorieAggressiveness = .moderate
    var weightLossPaceChoice: WeightLossPaceChoice = .moderate
    var advancedPaceDraft: WeightLossAdvancedPaceDraft = .default

    mutating func selectPaceChoice(_ choice: WeightLossPaceChoice) {
        weightLossPaceChoice = choice
        syncAggressivenessFromPaceChoice()
    }

    mutating func syncAggressivenessFromPaceChoice() {
        aggressiveness = weightLossPaceChoice.legacyAggressiveness
    }

    func isPaceApplicable() -> Bool {
        guard let current = parsedCurrentWeightKg, let goal = parsedGoalWeightKg else {
            return false
        }
        return goal < current - FormaCalculationConstants.goalDirectionEpsilonKg
    }

    func pacePreview(referenceDate: Date = Date()) -> WeightLossPacePreviewModel {
        guard isPaceApplicable(),
              let weightKg = parsedCurrentWeightKg,
              let goalWeightKg = parsedGoalWeightKg else {
            return .empty
        }

        return WeightLossPacePreviewBuilder.build(
            choice: weightLossPaceChoice,
            advancedDraft: advancedPaceDraft,
            weightKg: weightKg,
            goalWeightKg: goalWeightKg,
            referenceDate: referenceDate
        )
    }

    func paceDisplayLabel(result: CalorieTargetResult? = nil) -> String? {
        guard isPaceApplicable() else { return nil }

        if weightLossPaceChoice == .advanced {
            return "Custom"
        }

        return weightLossPaceChoice.displayName
    }

    func validate(step: OnboardingStep) throws {
        switch step {
        case .welcome:
            return
        case .body:
            _ = try parsePositiveInt(ageText, message: FormaProductCopy.Onboarding.Validation.age)
            _ = try parsePositiveDouble(heightCmText, message: FormaProductCopy.Onboarding.Validation.height)
            _ = try parsePositiveDouble(currentWeightKgText, message: FormaProductCopy.Onboarding.Validation.currentWeight)
            _ = try parseOptionalBodyFat(estimatedBodyFatPercentageText)
        case .goal:
            _ = try parsePositiveDouble(goalWeightKgText, message: FormaProductCopy.Onboarding.Validation.goalWeight)
            if isPaceApplicable() {
                let preview = pacePreview()
                guard preview.isSaveable else {
                    throw OnboardingFormError.invalid(
                        preview.validationError ?? FormaProductCopy.Error.checkInputs
                    )
                }
            }
        case .activity:
            _ = try parseNonNegativeInt(
                trainingFrequencyPerWeekText,
                message: FormaProductCopy.Onboarding.Validation.trainingFrequency
            )
            _ = try parseNonNegativeInt(averageStepsText, message: FormaProductCopy.Onboarding.Validation.averageSteps)
        case .preferences, .planPreview:
            return
        }
    }

    func validationMessage(for step: OnboardingStep) -> String? {
        do {
            try validate(step: step)
            return nil
        } catch let error as OnboardingFormError {
            return error.message
        } catch {
            return FormaProductCopy.Error.checkInputs
        }
    }

    func canAdvance(from step: OnboardingStep) -> Bool {
        switch step {
        case .welcome, .preferences, .planPreview:
            return true
        case .body, .goal, .activity:
            return validationMessage(for: step) == nil
        }
    }

    func makeCalorieTargetInput() throws -> CalorieTargetInput {
        let pace = try resolvedWeightLossPace()
        return CalorieTargetInput(
            age: try parsePositiveInt(ageText, message: FormaProductCopy.Onboarding.Validation.age),
            sex: sex,
            heightCm: try parsePositiveDouble(heightCmText, message: FormaProductCopy.Onboarding.Validation.height),
            weightKg: try parsePositiveDouble(currentWeightKgText, message: FormaProductCopy.Onboarding.Validation.currentWeight),
            goalWeightKg: try parsePositiveDouble(goalWeightKgText, message: FormaProductCopy.Onboarding.Validation.goalWeight),
            estimatedBodyFatPercentage: try parseOptionalBodyFat(estimatedBodyFatPercentageText),
            activityLevel: activityLevel,
            trainingFrequencyPerWeek: try parseNonNegativeInt(
                trainingFrequencyPerWeekText,
                message: FormaProductCopy.Onboarding.Validation.trainingFrequency
            ),
            averageSteps: try parseNonNegativeInt(
                averageStepsText,
                message: FormaProductCopy.Onboarding.Validation.averageSteps
            ),
            aggressiveness: weightLossPaceChoice.legacyAggressiveness,
            weightLossPace: pace
        )
    }

    func resolvedWeightLossPace() throws -> WeightLossPace {
        let weightKg = try parsePositiveDouble(
            currentWeightKgText,
            message: FormaProductCopy.Onboarding.Validation.currentWeight
        )
        let goalWeightKg = try parsePositiveDouble(
            goalWeightKgText,
            message: FormaProductCopy.Onboarding.Validation.goalWeight
        )
        let isCut = goalWeightKg < weightKg - FormaCalculationConstants.goalDirectionEpsilonKg

        guard isCut else {
            return weightLossPaceChoice.weightLossPace ?? .preset(.moderate)
        }

        return try WeightLossPaceChoiceResolver.resolvedPace(
            choice: weightLossPaceChoice,
            advancedDraft: advancedPaceDraft
        )
    }

    func makeUserProfileDraft(targets: UserTargets) throws -> UserProfileDraft {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDiet = dietPreference.trimmingCharacters(in: .whitespacesAndNewlines)

        return UserProfileDraft(
            name: trimmedName.isEmpty ? nil : trimmedName,
            age: try parsePositiveInt(ageText, message: FormaProductCopy.Onboarding.Validation.age),
            sex: sex,
            heightCm: try parsePositiveDouble(heightCmText, message: FormaProductCopy.Onboarding.Validation.height),
            currentWeightKg: try parsePositiveDouble(currentWeightKgText, message: FormaProductCopy.Onboarding.Validation.currentWeight),
            goalWeightKg: try parsePositiveDouble(goalWeightKgText, message: FormaProductCopy.Onboarding.Validation.goalWeight),
            estimatedBodyFatPercentage: try parseOptionalBodyFat(estimatedBodyFatPercentageText),
            activityLevel: activityLevel,
            trainingFrequencyPerWeek: try parseNonNegativeInt(
                trainingFrequencyPerWeekText,
                message: FormaProductCopy.Onboarding.Validation.trainingFrequency
            ),
            averageSteps: try parseNonNegativeInt(
                averageStepsText,
                message: FormaProductCopy.Onboarding.Validation.averageSteps
            ),
            dietPreference: trimmedDiet.isEmpty ? nil : trimmedDiet,
            unitSystem: unitSystem,
            targets: targets
        )
    }

    // MARK: - Parsed helpers

    var parsedCurrentWeightKg: Double? {
        parsedPositiveDouble(currentWeightKgText)
    }

    var parsedGoalWeightKg: Double? {
        parsedPositiveDouble(goalWeightKgText)
    }

    private func parsedPositiveDouble(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(trimmed), value > 0 else { return nil }
        return value
    }

    private func parsePositiveInt(_ text: String, message: String) throws -> Int {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Int(trimmed), value > 0 else {
            throw OnboardingFormError.invalid(message)
        }
        return value
    }

    private func parseNonNegativeInt(_ text: String, message: String) throws -> Int {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Int(trimmed), value >= 0 else {
            throw OnboardingFormError.invalid(message)
        }
        return value
    }

    private func parsePositiveDouble(_ text: String, message: String) throws -> Double {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(trimmed), value > 0 else {
            throw OnboardingFormError.invalid(message)
        }
        return value
    }

    private func parseOptionalBodyFat(_ text: String) throws -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let value = Double(trimmed), (0...80).contains(value) else {
            throw OnboardingFormError.invalid(FormaProductCopy.Onboarding.Validation.bodyFatRange)
        }
        return value
    }
}

enum OnboardingFormError: Error, Equatable {
    case invalid(String)

    var message: String {
        switch self {
        case .invalid(let message):
            return message
        }
    }
}
