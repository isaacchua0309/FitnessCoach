//
//  OnboardingStage.swift
//  Fitness Coach
//
//  Forma — Stage labels for onboarding v2 progress UI (not step counters).
//

import Foundation

/// Coarse onboarding phases shown in the progress header.
/// Maps several wizard steps onto one stage so the UI reads as a journey, not a form.
enum OnboardingStage: String, CaseIterable, Equatable, Sendable, Identifiable {
    case start
    case goal
    case basics
    case activity
    case preferences
    case plan
    case save

    var id: String { rawValue }

    var displayTitle: String {
        switch self {
        case .start:
            return "Getting started"
        case .goal:
            return "Your goal"
        case .basics:
            return "Your basics"
        case .activity:
            return "Activity & training"
        case .preferences:
            return "How you'll log"
        case .plan:
            return "Your plan"
        case .save:
            return "Save your plan"
        }
    }

    /// Short label for compact progress chips.
    var shortTitle: String {
        switch self {
        case .start:
            return "Start"
        case .goal:
            return "Goal"
        case .basics:
            return "Basics"
        case .activity:
            return "Activity"
        case .preferences:
            return "Preferences"
        case .plan:
            return "Plan"
        case .save:
            return "Save"
        }
    }

    /// 1-based index among stages for the progress bar fill.
    var progressIndex: Int {
        switch self {
        case .start: return 1
        case .goal: return 2
        case .basics: return 3
        case .activity: return 4
        case .preferences: return 5
        case .plan: return 6
        case .save: return 7
        }
    }

    static var stageCount: Int { allCases.count }

    /// Normalized progress in `0...1` for the current stage (stage entered, not completed).
    var progressFraction: Double {
        Double(progressIndex) / Double(Self.stageCount)
    }

    /// Whole-number percentage for optional display (e.g. "43%").
    var progressPercent: Int {
        Int((progressFraction * 100).rounded())
    }

    var progressAccessibilityLabel: String {
        "\(displayTitle), \(progressIndex) of \(Self.stageCount)"
    }

    var previous: OnboardingStage? {
        guard let index = Self.allCases.firstIndex(of: self), index > 0 else { return nil }
        return Self.allCases[index - 1]
    }

    var next: OnboardingStage? {
        guard let index = Self.allCases.firstIndex(of: self),
              index < Self.allCases.count - 1 else { return nil }
        return Self.allCases[index + 1]
    }
}
