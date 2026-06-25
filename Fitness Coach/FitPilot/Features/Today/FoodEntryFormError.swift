//
//  FoodEntryFormError.swift
//  Fitness Coach
//
//  FitPilot AI — Validation errors for manual food entry forms.
//

import Foundation

enum FoodEntryFormError: LocalizedError, Equatable {
    case missingName
    case invalidCalories
    case invalidProtein
    case invalidCarbs
    case invalidFat
    case invalidQuantity
    case invalidFiber
    case invalidSodium

    var errorDescription: String? {
        switch self {
        case .missingName:
            return "Please enter a food name."
        case .invalidCalories:
            return "Calories must be zero or more."
        case .invalidProtein:
            return "Protein must be zero or more."
        case .invalidCarbs:
            return "Carbs must be zero or more."
        case .invalidFat:
            return "Fat must be zero or more."
        case .invalidQuantity:
            return "Quantity must be greater than zero."
        case .invalidFiber:
            return "Fiber must be zero or more."
        case .invalidSodium:
            return "Sodium must be zero or more."
        }
    }
}
