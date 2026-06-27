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
}

extension FoodEntryFormMode {
    var showsAdvancedNutrients: Bool {
        switch self {
        case .coachEdit: return false
        case .manualEntry: return true
        }
    }

    var showsUserNotes: Bool {
        switch self {
        case .coachEdit: return false
        case .manualEntry: return true
        }
    }

    var showsEstimateBanner: Bool {
        if case .coachEdit = self { return true }
        return false
    }
}
