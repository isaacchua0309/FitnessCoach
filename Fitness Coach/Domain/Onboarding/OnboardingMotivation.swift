//
//  OnboardingMotivation.swift
//  Fitness Coach
//
//  Forma — Optional motivation selections for onboarding v2 (not required for plan math).
//

import Foundation

enum OnboardingMotivation: String, Codable, CaseIterable, Equatable, Sendable, Identifiable {
    case confidence
    case health
    case energy
    case performance
    case discipline
    case lowStress
    case other

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
        case .other:
            return "Something else"
        }
    }

    var subtitle: String {
        switch self {
        case .confidence:
            return "Steady progress you can trust, without extremes."
        case .health:
            return "Support markers like sleep, recovery, and how you feel."
        case .energy:
            return "Fuel your days without running on empty."
        case .performance:
            return "Protect training while nutrition supports your goal."
        case .discipline:
            return "Small repeats beat perfect weeks."
        case .lowStress:
            return "No streak guilt — just honest logging when you can."
        case .other:
            return "Forma adapts as your reason becomes clearer."
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
        case .other:
            return "ellipsis.circle"
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
        case .other:
            return "Personal reasons"
        }
    }
}

extension OnboardingMotivation {

    /// Motivation is optional during onboarding; empty selection is always valid.
    static var allowsEmptySelection: Bool { true }

    static func fromStoredValues(_ values: [String]) -> Set<OnboardingMotivation> {
        Set(values.compactMap(OnboardingMotivation.init(rawValue:)))
    }

    /// Chooses calm feedback when one or more motivations are selected.
    static func feedbackMessage(for selections: Set<OnboardingMotivation>) -> String {
        let copy = FormaProductCopy.Onboarding.V2.Motivation.self
        if selections.contains(.confidence) {
            return copy.confidenceFeedback
        }
        if selections.contains(.performance) {
            return copy.performanceFeedback
        }
        if selections.contains(.lowStress) {
            return copy.lowStressFeedback
        }
        return copy.defaultFeedback
    }
}
