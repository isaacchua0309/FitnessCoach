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
    var aggressiveness: CalorieAggressiveness = .moderate

    func validate(step: OnboardingStep) throws {
        switch step {
        case .welcome:
            return
        case .body:
            _ = try parsePositiveInt(ageText, message: "Please enter a valid age.")
            _ = try parsePositiveDouble(heightCmText, message: "Please enter a valid height.")
            _ = try parsePositiveDouble(currentWeightKgText, message: "Please enter your current weight.")
            _ = try parseOptionalBodyFat(estimatedBodyFatPercentageText)
        case .goal:
            _ = try parsePositiveDouble(goalWeightKgText, message: "Please enter your goal weight.")
        case .activity:
            _ = try parseNonNegativeInt(
                trainingFrequencyPerWeekText,
                message: "Training frequency must be zero or greater."
            )
            _ = try parseNonNegativeInt(averageStepsText, message: "Average steps must be zero or greater.")
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
            return "Please check your inputs."
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
        CalorieTargetInput(
            age: try parsePositiveInt(ageText, message: "Please enter a valid age."),
            sex: sex,
            heightCm: try parsePositiveDouble(heightCmText, message: "Please enter a valid height."),
            weightKg: try parsePositiveDouble(currentWeightKgText, message: "Please enter your current weight."),
            goalWeightKg: try parsePositiveDouble(goalWeightKgText, message: "Please enter your goal weight."),
            estimatedBodyFatPercentage: try parseOptionalBodyFat(estimatedBodyFatPercentageText),
            activityLevel: activityLevel,
            trainingFrequencyPerWeek: try parseNonNegativeInt(
                trainingFrequencyPerWeekText,
                message: "Training frequency must be zero or greater."
            ),
            averageSteps: try parseNonNegativeInt(
                averageStepsText,
                message: "Average steps must be zero or greater."
            ),
            aggressiveness: aggressiveness
        )
    }

    func makeUserProfileDraft(targets: UserTargets) throws -> UserProfileDraft {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDiet = dietPreference.trimmingCharacters(in: .whitespacesAndNewlines)

        return UserProfileDraft(
            name: trimmedName.isEmpty ? nil : trimmedName,
            age: try parsePositiveInt(ageText, message: "Please enter a valid age."),
            sex: sex,
            heightCm: try parsePositiveDouble(heightCmText, message: "Please enter a valid height."),
            currentWeightKg: try parsePositiveDouble(currentWeightKgText, message: "Please enter your current weight."),
            goalWeightKg: try parsePositiveDouble(goalWeightKgText, message: "Please enter your goal weight."),
            estimatedBodyFatPercentage: try parseOptionalBodyFat(estimatedBodyFatPercentageText),
            activityLevel: activityLevel,
            trainingFrequencyPerWeek: try parseNonNegativeInt(
                trainingFrequencyPerWeekText,
                message: "Training frequency must be zero or greater."
            ),
            averageSteps: try parseNonNegativeInt(
                averageStepsText,
                message: "Average steps must be zero or greater."
            ),
            dietPreference: trimmedDiet.isEmpty ? nil : trimmedDiet,
            unitSystem: unitSystem,
            targets: targets
        )
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
            throw OnboardingFormError.invalid("Body fat must be between 0 and 80.")
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
