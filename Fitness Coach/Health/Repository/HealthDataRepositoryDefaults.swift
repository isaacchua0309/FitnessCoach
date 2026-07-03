//
//  HealthDataRepositoryDefaults.swift
//  Fitness Coach
//
//  Forma — Sensible default lookback windows for HealthDataRepository.
//

import Foundation

enum HealthDataRepositoryDefaults {

    static let recentWorkoutsDays = 14
    static let recentSleepDays = 14
    static let recentHeartMetricsDays = 30
    static let bodyMassHistoryDays = 90
    static let refreshDays = 7

    static func resolvedDays(_ days: Int, default defaultDays: Int) -> Int {
        days > 0 ? days : defaultDays
    }
}
