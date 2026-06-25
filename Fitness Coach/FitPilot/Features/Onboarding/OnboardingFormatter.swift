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
            return "Lightly active"
        case .moderatelyActive:
            return "Moderately active"
        case .veryActive:
            return "Very active"
        case .athlete:
            return "Athlete"
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

    static func unitSystem(_ unitSystem: UnitSystem) -> String {
        switch unitSystem {
        case .metric:
            return "Metric (kg, cm)"
        case .imperial:
            return "Imperial (display preference)"
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
            : "\(String(format: "%.1f", value)) kg/week"
    }
}
