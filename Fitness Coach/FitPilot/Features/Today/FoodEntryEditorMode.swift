//
//  FoodEntryEditorMode.swift
//  Fitness Coach
//
//  FitPilot AI — Add vs edit mode for manual food entry.
//

import Foundation

enum FoodEntryEditorMode: Equatable {
    case add
    case edit(FoodEntry)

    var title: String {
        switch self {
        case .add:
            return "Add Food"
        case .edit:
            return "Edit Food"
        }
    }

    var entry: FoodEntry? {
        switch self {
        case .add:
            return nil
        case .edit(let entry):
            return entry
        }
    }
}
