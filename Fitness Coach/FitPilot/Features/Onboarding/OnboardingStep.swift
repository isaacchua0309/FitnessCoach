//
//  OnboardingStep.swift
//  Fitness Coach
//
//  FitPilot AI — Onboarding step definitions.
//

import Foundation

enum OnboardingStep: Int, CaseIterable, Identifiable, Equatable {
    case welcome
    case body
    case goal
    case activity
    case preferences
    case planPreview

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .welcome:
            return "Welcome to FitPilot"
        case .body:
            return "Your body details"
        case .goal:
            return "Your goal"
        case .activity:
            return "Your activity"
        case .preferences:
            return "Preferences"
        case .planPreview:
            return "Your plan"
        }
    }

    var subtitle: String {
        switch self {
        case .welcome:
            return "Set up your targets in under a minute."
        case .body:
            return "We use these to estimate your calorie and macro needs."
        case .goal:
            return "Choose a goal weight and pace that feels sustainable."
        case .activity:
            return "Tell us how active you are day to day."
        case .preferences:
            return "Optional details to personalize your experience."
        case .planPreview:
            return "Review your generated targets before starting."
        }
    }

    var progressIndex: Int {
        switch self {
        case .welcome: return 1
        case .body: return 2
        case .goal: return 3
        case .activity: return 4
        case .preferences: return 5
        case .planPreview: return 6
        }
    }

    static var totalSteps: Int { allCases.count }

    var previous: OnboardingStep? {
        OnboardingStep(rawValue: rawValue - 1)
    }

    var next: OnboardingStep? {
        OnboardingStep(rawValue: rawValue + 1)
    }
}
