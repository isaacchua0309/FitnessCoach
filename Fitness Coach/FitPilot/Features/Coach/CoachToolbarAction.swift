//
//  CoachToolbarAction.swift
//  Fitness Coach
//
//  FitPilot AI — Persistent Coach toolbar commands.
//

import Foundation

enum CoachToolbarActionBehavior: Sendable {
    case prefill(String)
    case send(String)
    case openPhotoPicker
}

enum CoachToolbarAction: String, Identifiable, Sendable, CaseIterable {
    case meal
    case water
    case weight
    case workout
    case photo
    case protein
    case recovery
    case mealIdeas
    case dailyReview
    case tomorrow
    case status

    var id: String { rawValue }

    /// Coach is for logging. Overview commands rank lowest — Today and Journey cover those.
    enum Category: Sendable {
        case logging
        case coaching
        case overview
    }

    var category: Category {
        switch self {
        case .meal, .water, .weight, .workout, .photo, .protein:
            return .logging
        case .recovery, .mealIdeas:
            return .coaching
        case .status, .dailyReview, .tomorrow:
            return .overview
        }
    }

    /// Static importance when usage is equal. Higher appears further left.
    var basePriority: Int {
        switch self {
        case .meal: return 100
        case .water: return 95
        case .photo: return 90
        case .weight: return 85
        case .workout: return 80
        case .protein: return 75
        case .recovery: return 70
        case .mealIdeas: return 45
        case .dailyReview: return 30
        case .tomorrow: return 25
        case .status: return 10
        }
    }

    var label: String {
        switch self {
        case .meal: return "Meal"
        case .water: return "Water"
        case .weight: return "Weight"
        case .workout: return "Workout"
        case .photo: return "Photo"
        case .protein: return "Protein"
        case .recovery: return "Recovery"
        case .status: return "Status"
        case .dailyReview: return "Daily Review"
        case .tomorrow: return "Tomorrow"
        case .mealIdeas: return "Meal Ideas"
        }
    }

    var symbolName: String {
        switch self {
        case .meal: return "fork.knife"
        case .water: return "drop.fill"
        case .weight: return "scalemass"
        case .workout: return "dumbbell.fill"
        case .photo: return "camera"
        case .protein: return "bolt.fill"
        case .recovery: return "figure.cooldown"
        case .status: return "chart.bar"
        case .dailyReview: return "sun.horizon"
        case .tomorrow: return "calendar"
        case .mealIdeas: return "leaf"
        }
    }

    var behavior: CoachToolbarActionBehavior {
        switch self {
        case .meal:
            return .prefill("Log my meal: ")
        case .water:
            return .send("Add 500ml water")
        case .weight:
            return .prefill("Log weight: ")
        case .workout:
            return .prefill("Log my workout: ")
        case .photo:
            return .openPhotoPicker
        case .protein:
            return .send("Log a high-protein meal")
        case .recovery:
            return .send("How should I recover from today's workout?")
        case .status:
            return .send("status")
        case .dailyReview:
            return .send("daily review")
        case .tomorrow:
            return .send("What should I focus on tomorrow?")
        case .mealIdeas:
            return .send("What should I eat next?")
        }
    }

    var accessibilityHint: String {
        switch behavior {
        case .prefill: return "Prefills the message field"
        case .send: return "Sends this command to Coach"
        case .openPhotoPicker: return "Opens photo picker for meal analysis"
        }
    }
}
