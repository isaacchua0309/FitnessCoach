//
//  OnboardingLoggingPreference.swift
//  Fitness Coach
//
//  Forma — Optional logging style preferences for low-pressure Coach setup.
//

import Foundation

enum OnboardingLoggingPreference: String, Codable, CaseIterable, Equatable, Sendable, Identifiable {
    case naturalLanguage
    case quickTaps
    case dailyCheckIns
    case noPressure

    var id: String { rawValue }

    var title: String {
        switch self {
        case .naturalLanguage:
            return "Natural-language logging"
        case .quickTaps:
            return "Quick taps"
        case .dailyCheckIns:
            return "Daily check-ins"
        case .noPressure:
            return "No pressure"
        }
    }

    var subtitle: String {
        switch self {
        case .naturalLanguage:
            return "Tell Coach what you ate or did in plain words."
        case .quickTaps:
            return "Use starter chips when you want speed over detail."
        case .dailyCheckIns:
            return "A short end-of-day recap is enough some days."
        case .noPressure:
            return "Skip days without guilt — pick up when life allows."
        }
    }

    var symbolName: String {
        switch self {
        case .naturalLanguage:
            return "bubble.left.and.bubble.right.fill"
        case .quickTaps:
            return "hand.tap.fill"
        case .dailyCheckIns:
            return "checkmark.circle"
        case .noPressure:
            return "tortoise.fill"
        }
    }
}

extension OnboardingLoggingPreference {

    /// Logging preferences are optional during onboarding.
    static var allowsEmptySelection: Bool { true }

    static func fromStoredValues(_ values: [String]) -> Set<OnboardingLoggingPreference> {
        Set(values.compactMap(OnboardingLoggingPreference.init(rawValue:)))
    }
}
