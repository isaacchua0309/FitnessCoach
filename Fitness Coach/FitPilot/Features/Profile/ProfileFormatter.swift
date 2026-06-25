//
//  ProfileFormatter.swift
//  Fitness Coach
//
//  FitPilot AI — Lightweight Profile display formatting.
//
//  Formatting only. No services, AI, SwiftData, or target formulas.
//

import Foundation

enum ProfileFormatter {
    static func name(_ name: String?) -> String {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "Not set" : trimmed
    }

    static func age(_ age: Int) -> String {
        "\(age) years"
    }

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

    static func unitSystem(_ unitSystem: UnitSystem) -> String {
        switch unitSystem {
        case .metric:
            return "Metric (kg, cm, ml)"
        case .imperial:
            return "Imperial (display preference)"
        }
    }

    static func dietPreference(_ preference: String?) -> String {
        let trimmed = preference?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "None set" : trimmed
    }

    static func cm(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value)) cm"
            : "\(String(format: "%.1f", value)) cm"
    }

    static func kg(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value)) kg"
            : "\(String(format: "%.1f", value)) kg"
    }

    static func optionalKg(_ value: Double?) -> String? {
        guard let value else { return nil }
        return kg(value)
    }

    static func percent(_ value: Double?) -> String? {
        guard let value else { return nil }
        return value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value))%"
            : "\(String(format: "%.1f", value))%"
    }

    static func kcal(_ value: Int) -> String {
        "\(value) kcal"
    }

    static func grams(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value)) g"
            : "\(String(format: "%.1f", value)) g"
    }

    static func gramsCompact(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value))g"
            : "\(String(format: "%.1f", value))g"
    }

    static func ml(_ value: Int) -> String {
        "\(value) ml"
    }

    static func mlCompact(_ value: Int) -> String {
        "\(value)ml"
    }

    static func steps(_ value: Int) -> String {
        "\(value) steps/day"
    }

    static func stepsCompact(_ value: Int) -> String {
        "\(value)/day"
    }

    static func trainingFrequency(_ value: Int) -> String {
        value == 1 ? "1 day/week" : "\(value) days/week"
    }

    static func weeklyLoss(_ value: Double?) -> String? {
        guard let value else { return nil }
        return value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value)) kg/week"
            : "\(String(format: "%.1f", value)) kg/week"
    }

    static func monthYear(_ date: Date?) -> String {
        guard let date else { return "—" }
        return date.formatted(.dateTime.month(.abbreviated).year())
    }

    static func monthYearLong(_ date: Date?) -> String {
        guard let date else { return "—" }
        return date.formatted(.dateTime.month(.wide).year())
    }
}
