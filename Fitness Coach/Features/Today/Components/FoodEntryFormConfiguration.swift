//
//  FoodEntryFormConfiguration.swift
//  Fitness Coach
//
//  FitPilot AI — Display mode for food entry forms.
//

import Foundation

enum FoodEntryFormMode: Equatable {
    case coachEdit(estimateContext: String?, confidence: AIConfidence)
    case manualEntry
    /// Today sheet — name, meal type, and core macros only.
    case todayManualEntry
}

extension FoodEntryFormMode {
    var showsPortionFields: Bool {
        switch self {
        case .coachEdit, .manualEntry: return true
        case .todayManualEntry: return false
        }
    }

    var showsAdvancedNutrients: Bool {
        switch self {
        case .manualEntry: return true
        case .coachEdit, .todayManualEntry: return false
        }
    }

    var showsUserNotes: Bool {
        switch self {
        case .manualEntry: return true
        case .coachEdit, .todayManualEntry: return false
        }
    }

    var showsEstimateBanner: Bool {
        if case .coachEdit = self { return true }
        return false
    }
}
