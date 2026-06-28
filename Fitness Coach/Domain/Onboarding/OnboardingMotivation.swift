//
//  OnboardingMotivation.swift
//  Fitness Coach
//
//  Forma — Optional motivation selections for onboarding (not required for plan math).
//

import Foundation

enum OnboardingMotivation: String, Codable, CaseIterable, Equatable, Sendable, Identifiable {
    case confidence
    case health
    case energy
    case performance
    case discipline
    case lowStress

    var id: String { rawValue }

    var title: String {
        switch self {
        case .confidence:
            return "Feel confident in clothes"
        case .health:
            return "Improve health"
        case .energy:
            return "Have more energy"
        case .performance:
            return "Perform better in training"
        case .discipline:
            return "Build discipline"
        case .lowStress:
            return "Reduce stress around food"
        }
    }

    var subtitle: String {
        switch self {
        case .confidence:
            return "Steady progress without extremes."
        case .health:
            return "Support sleep, recovery, and how you feel."
        case .energy:
            return "Fuel your day without running empty."
        case .performance:
            return "Protect performance while cutting."
        case .discipline:
            return "Small repeats beat perfect weeks."
        case .lowStress:
            return "Log honestly without guilt."
        }
    }

    /// SF Symbol name for selection cards.
    var symbolName: String {
        switch self {
        case .confidence:
            return "sparkles"
        case .health:
            return "heart.fill"
        case .energy:
            return "bolt.fill"
        case .performance:
            return "figure.strengthtraining.traditional"
        case .discipline:
            return "calendar"
        case .lowStress:
            return "leaf.fill"
        }
    }

    /// Short label for personalization summary recap.
    var recapLabel: String {
        switch self {
        case .confidence:
            return "Confidence"
        case .health:
            return "Health"
        case .energy:
            return "Energy"
        case .performance:
            return "Training performance"
        case .discipline:
            return "Discipline"
        case .lowStress:
            return "Low stress"
        }
    }
}

extension OnboardingMotivation {

    /// Motivation is optional during onboarding; empty selection is always valid.
    static var allowsEmptySelection: Bool { true }

    /// Maximum motivations the user can pick during onboarding.
    static let maxSelectionCount = 2

    static func fromStoredValues(_ values: [String]) -> Set<OnboardingMotivation> {
        Set(values.compactMap(OnboardingMotivation.init(rawValue:)))
    }
}
