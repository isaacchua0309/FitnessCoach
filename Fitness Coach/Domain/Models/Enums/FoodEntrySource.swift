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
