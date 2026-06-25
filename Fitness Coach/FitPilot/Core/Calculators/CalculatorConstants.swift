//
//  CalculatorConstants.swift
//  Fitness Coach
//
//  FitPilot AI — Shared deterministic calculation constants.
//

import Foundation

enum CalculatorConstants {
    static let kcalPerKgFat = 7700.0
    static let proteinKcalPerGram = 4.0
    static let carbKcalPerGram = 4.0
    static let fatKcalPerGram = 9.0

    /// Minimum number of days of data required before a maintenance estimate is
    /// considered meaningful.
    static let minimumMaintenanceDays = 7
}
