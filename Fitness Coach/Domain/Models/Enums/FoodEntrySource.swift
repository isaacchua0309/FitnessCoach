//
//  FoodEntrySource.swift
//  Fitness Coach
//
//  FitPilot AI — Core domain enums.
//

import Foundation

enum FoodEntrySource: String, Codable, CaseIterable, Equatable, Sendable {
    case manual
    case aiTextEstimate
    case aiPhotoEstimate
    case nutritionLabel
    case savedMeal
    case corrected
}

extension FoodEntrySource {
    /// True when calories came from an AI estimate the user reviewed before logging.
    var isReviewedEstimate: Bool {
        switch self {
        case .aiTextEstimate, .aiPhotoEstimate, .corrected:
            return true
        case .manual, .nutritionLabel, .savedMeal:
            return false
        }
    }
}
