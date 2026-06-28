//
//  OnboardingStage.swift
//  Fitness Coach
//
//  Forma — Coarse onboarding phases for the progress header.
//

import Foundation

enum OnboardingStage: String, CaseIterable, Equatable, Sendable, Identifiable {
    case start
    case body
    case destination
    case activity
    case proof
    case plan
    case save

    var id: String { rawValue }

    var progressIndex: Int {
        switch self {
        case .start: return 1
        case .body: return 2
        case .destination: return 3
        case .activity: return 4
        case .proof: return 5
        case .plan: return 6
        case .save: return 7
        }
    }

    static var stageCount: Int { allCases.count }

    var progressAccessibilityLabel: String {
        "\(displayTitle), \(progressIndex) of \(Self.stageCount)"
    }

    var displayTitle: String {
        switch self {
        case .start:
            return "Getting started"
        case .body:
            return "Your basics"
        case .destination:
            return "Your destination"
        case .activity:
            return "Activity"
        case .proof:
            return "Why Forma"
        case .plan:
            return "Your plan"
        case .save:
            return "Save your plan"
        }
    }
}
