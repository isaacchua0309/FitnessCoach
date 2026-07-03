//
//  FoodEntryFormConfiguration.swift
//  Fitness Coach
//
//  FitPilot AI — Display mode for food entry forms.
//
//  Manual meal form is fallback/editing, not primary logging.
//  Today routes new logs through Coach (photo, voice, text). This form remains for:
//  - editing an existing Today entry (`editNutrition`)
//  - creating a custom food when no estimate exists (`createCustomFood`)
//  - correcting a Coach estimate before logging (`coachEdit`)
//  See Docs/TodayMealLogging.md.
//

import Foundation

enum FoodEntryFormMode: Equatable {
    /// Coach confirmation — adjust an AI estimate before logging.
    case coachEdit(estimateContext: String?, confidence: AIConfidence)
    /// Full form for custom food creation (fallback, tests, debug — not shown on Today).
    case createCustomFood
    /// Today edit sheet — name, meal type, and core macros for an existing entry.
    case editNutrition
}

extension FoodEntryFormMode {
    var showsPortionFields: Bool {
        switch self {
        case .coachEdit, .createCustomFood: return true
        case .editNutrition: return false
        }
    }

    var showsAdvancedNutrients: Bool {
        switch self {
        case .createCustomFood: return true
        case .coachEdit, .editNutrition: return false
        }
    }

    var showsUserNotes: Bool {
        switch self {
        case .createCustomFood: return true
        case .coachEdit, .editNutrition: return false
        }
    }

    var showsEstimateBanner: Bool {
        if case .coachEdit = self { return true }
        return false
    }
}
