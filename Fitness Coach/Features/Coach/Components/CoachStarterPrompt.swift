//
//  CoachStarterPrompt.swift
//  Fitness Coach
//
//  FitPilot AI — Tappable empty-state starters (shown once, not a persistent toolbar).
//

import Foundation

enum CoachStarterPromptBehavior: Equatable, Sendable {
    case prefill(String)
    case send(String)
    case openPhotoPicker
}

struct CoachStarterPromptSpec: Identifiable, Equatable, Sendable {
    let id: String
    let label: String
    let symbolName: String
    let behavior: CoachStarterPromptBehavior
    let accessibilityHint: String
}

enum CoachStarterPrompt: String, Identifiable, CaseIterable, Sendable {
    case logMeal
    case logWater
    case logWorkout
    case status
    case mealPhoto
    case dailyReview

    var id: String { rawValue }

    var label: String {
        switch self {
        case .logMeal: return "Log a meal"
        case .logWater: return "Add 500ml water"
        case .logWorkout: return "Log workout"
        case .status: return "Today's status"
        case .mealPhoto: return "Photo meal"
        case .dailyReview: return "Daily review"
        }
    }

    var symbolName: String {
        switch self {
        case .logMeal: return "fork.knife"
        case .logWater: return "drop.fill"
        case .logWorkout: return "dumbbell.fill"
        case .status: return "chart.bar"
        case .mealPhoto: return "camera"
        case .dailyReview: return "sun.horizon"
        }
    }

    var behavior: CoachStarterPromptBehavior {
        switch self {
        case .logMeal:
            return .prefill("Log ")
        case .logWater:
            return .send("Add 500ml water")
        case .logWorkout:
            return .prefill("Log my workout: ")
        case .status:
            return .send("status")
        case .mealPhoto:
            return .openPhotoPicker
        case .dailyReview:
            return .send("daily review")
        }
    }

    var accessibilityHint: String {
        switch behavior {
        case .prefill: return "Prefills the message field"
        case .send: return "Sends this command to Coach"
        case .openPhotoPicker: return "Opens photo picker for meal analysis"
        }
    }

    /// Curated starters for the Coach empty state (full set remains in `allCases`).
    static let quickActions: [CoachStarterPrompt] = [
        .logMeal,
        .logWater,
        .mealPhoto,
        .dailyReview
    ]

    var spec: CoachStarterPromptSpec {
        CoachStarterPromptSpec(
            id: id,
            label: label,
            symbolName: symbolName,
            behavior: behavior,
            accessibilityHint: accessibilityHint
        )
    }

    static var defaultQuickActionSpecs: [CoachStarterPromptSpec] {
        quickActions.map(\.spec)
    }
}
