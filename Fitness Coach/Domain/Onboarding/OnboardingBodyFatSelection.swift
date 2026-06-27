//
//  OnboardingBodyFatSelection.swift
//  Fitness Coach
//
//  Forma — Optional body-fat chip presets for tap-first onboarding.
//

import Foundation

enum OnboardingBodyFatPreset: String, CaseIterable, Identifiable, Equatable, Sendable {
    case unknown
    case fifteen
    case twenty
    case twentyFive
    case thirty
    case custom

    var id: String { rawValue }

    static let presetPercentages = [15, 20, 25, 30]

    var title: String {
        switch self {
        case .unknown:
            return "I don't know"
        case .fifteen:
            return "15%"
        case .twenty:
            return "20%"
        case .twentyFive:
            return "25%"
        case .thirty:
            return "30%"
        case .custom:
            return "Custom"
        }
    }

    var storedPercentage: String? {
        switch self {
        case .unknown:
            return nil
        case .fifteen:
            return "15"
        case .twenty:
            return "20"
        case .twentyFive:
            return "25"
        case .thirty:
            return "30"
        case .custom:
            return nil
        }
    }

    static func inferred(from text: String) -> OnboardingBodyFatPreset? {
        let normalized = OnboardingFormState.normalizedBodyFatText(text)
        guard !normalized.isEmpty else { return nil }

        if let value = Int(normalized), presetPercentages.contains(value) {
            switch value {
            case 15: return .fifteen
            case 20: return .twenty
            case 25: return .twentyFive
            case 30: return .thirty
            default: return .custom
            }
        }

        if Double(normalized) != nil {
            return .custom
        }

        return .custom
    }
}

extension OnboardingFormState {

    var bodyFatPreset: OnboardingBodyFatPreset? {
        OnboardingBodyFatPreset.inferred(from: estimatedBodyFatPercentageText)
    }

    mutating func selectBodyFatPreset(_ preset: OnboardingBodyFatPreset) {
        switch preset {
        case .unknown:
            estimatedBodyFatPercentageText = ""
        case .custom:
            break
        case .fifteen, .twenty, .twentyFive, .thirty:
            estimatedBodyFatPercentageText = preset.storedPercentage ?? ""
        }
    }

    mutating func applyBodyBasicsDefaultsIfNeeded() {
        if ageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            ageText = String(OnboardingV3PickerDefaults.defaultAge)
        }
        if heightCmText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            heightCmText = Self.formatStoredMetric(OnboardingV3PickerDefaults.defaultHeightCm)
        }
        if currentWeightKgText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            currentWeightKgText = Self.formatStoredMetric(OnboardingV3PickerDefaults.defaultWeightKg)
        }
    }

    private static func formatStoredMetric(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.1f", value)
        }
        return String(format: "%.2f", value)
    }
}
