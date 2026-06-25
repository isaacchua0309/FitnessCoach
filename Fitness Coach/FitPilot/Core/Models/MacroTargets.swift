//
//  MacroTargets.swift
//  Fitness Coach
//
//  FitPilot AI — Core app-facing model.
//

import Foundation

struct MacroTargets: Codable, Equatable, Sendable {
    var calories: Int
    var protein: Double
    var carbs: Double
    var fat: Double
}
