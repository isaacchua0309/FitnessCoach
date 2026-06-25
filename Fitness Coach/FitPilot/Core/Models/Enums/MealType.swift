//
//  MealType.swift
//  Fitness Coach
//
//  FitPilot AI — Core domain enums.
//

import Foundation

enum MealType: String, Codable, CaseIterable, Equatable, Sendable {
    case breakfast
    case lunch
    case dinner
    case snack
    case unknown
}
