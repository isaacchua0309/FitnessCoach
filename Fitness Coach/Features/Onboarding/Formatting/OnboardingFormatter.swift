//
//  OnboardingFormatter.swift
//  Fitness Coach
//
//  FitPilot AI — Lightweight Onboarding display formatting.
//
//  Formatting only. No services, AI, SwiftData, or target formulas.
//

import Foundation

enum OnboardingFormatter {
    static func sex(_ sex: Sex) -> String {
        switch sex {
        case .male:
            return "Male"
        case .female:
            return "Female"
        case .other:
            return "Other"
        case .preferNotToSay:
            return "Prefer not to say"
        }
    }

    static func activityLevel(_ level: ActivityLevel) -> String {
        switch level {
        case .sedentary:
            return "Sedentary"
        case .lightlyActive:
            return "Lightly Active"
        case .moderatelyActive:
            return "Moderately Active"
        case .veryActive:
            return "Very Active"
        case .athlete:
            return "Extra Active"
        }
    }

    static func activityLevelDescription(_ level: ActivityLevel) -> String {
        switch level {
        case .sedentary:
            return "Mostly sitting, minimal planned movement."
        case .lightlyActive:
            return "Light walking or occasional exercise."
        case .moderatelyActive:
            return "Regular training or active days most weeks."
        case .veryActive:
            return "Hard training, active job, or high step count."
        case .athlete:
            return "Structured performance training and high recovery demand."
        }
    }

    static func aggressiveness(_ aggressiveness: CalorieAggressiveness) -> String {
        switch aggressiveness {
        case .conservative:
            return "Conservative"
        case .moderate:
            return "Moderate"
        case .aggressive:
            return "Aggressive"
        }
    }

    static func aggressivenessDescription(_ aggressiveness: CalorieAggressiveness) -> String {
        switch aggressiveness {
        case .conservative:
            return "Slower progress, easier to sustain."
        case .moderate:
            return "Balanced pace for most people."
        case .aggressive:
            return "Faster progress, but harder to sustain. Pay attention to energy and recovery."
        }
    }

    static func paceChoiceTitle(_ choice: WeightLossPaceChoice) -> String {
        switch choice {
        case .gentle:
            return "Gentle"
        case .moderate:
            return "Moderate"
        case .aggressive:
            return "Aggressive"
        case .advanced:
            return "Advanced"
        }
    }

    static func safetyDisplay(_ display: WeightLossPaceSafetyDisplay) -> String {
        display.rawValue
    }

    static func monthlyLoss(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value)) kg/month"
            : String(format: "%.1f kg/month", value)
    }

    static func unitSystem(_ unitSystem: UnitSystem) -> String {
        switch unitSystem {
        case .metric:
            return "Metric (kg, cm)"
        case .imperial:
            return "Imperial (display preference)"
        }
    }

    static func heightUnitLabel(for unitSystem: UnitSystem) -> String {
        switch unitSystem {
        case .metric:
            return "Centimeters"
        case .imperial:
            return "Inches"
        }
    }

    static func weightUnitLabel(for unitSystem: UnitSystem) -> String {
        switch unitSystem {
        case .metric:
            return "Kilograms"
        case .imperial:
            return "Pounds"
        }
    }

    static func heightPlaceholder(for unitSystem: UnitSystem) -> String {
        switch unitSystem {
        case .metric:
            return "175"
        case .imperial:
            return "69"
        }
    }

    static func weightUnitAbbreviation(for unitSystem: UnitSystem) -> String {
        switch unitSystem {
        case .metric:
            return "kg"
        case .imperial:
            return "lb"
        }
    }

    static func weightPlaceholder(for unitSystem: UnitSystem) -> String {
        switch unitSystem {
        case .metric:
            return "82.5"
        case .imperial:
            return "182"
        }
    }

    static func kcal(_ value: Int) -> String {
        "\(value) kcal"
    }

    static func grams(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value)) g"
            : "\(String(format: "%.1f", value)) g"
    }

    static func ml(_ value: Int) -> String {
        "\(value) ml"
    }

    static func weeklyLoss(_ value: Double?) -> String? {
        guard let value else { return nil }
        return value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value)) kg/week"
            : "\(String(format: "%.2f", value)) kg/week"
    }
}
