//
//  UserTargets.swift
//  Fitness Coach
//
//  FitPilot AI — Core app-facing model.
//

import Foundation

struct UserTargets: Codable, Equatable, Sendable {
    var calorieTarget: Int
    var proteinTarget: Double
    var carbTarget: Double
    var fatTarget: Double
    var waterTargetMl: Int
    var expectedWeeklyWeightLossKg: Double?
    var aggressiveness: CalorieAggressiveness
}
