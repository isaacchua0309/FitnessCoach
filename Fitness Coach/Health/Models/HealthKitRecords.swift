//
//  HealthKitRecords.swift
//  Fitness Coach
//
//  Forma — HealthKit-agnostic fetch results from HealthKitManager.
//

import Foundation

struct HealthDailyMetrics: Equatable, Sendable {
    let date: Date
    let steps: Int?
    let activeEnergyKcal: Double?
    let exerciseMinutes: Double?

    static func empty(for date: Date) -> HealthDailyMetrics {
        HealthDailyMetrics(date: date, steps: nil, activeEnergyKcal: nil, exerciseMinutes: nil)
    }
}

struct HealthFetchedWorkout: Equatable, Sendable, Identifiable {
    let id: UUID
    let activityTypeName: String
    let startDate: Date
    let endDate: Date
    let durationMinutes: Int
    let activeCaloriesKcal: Double?
    let sourceName: String?
}

struct HealthSleepRecord: Equatable, Sendable, Identifiable {
    let id: UUID
    let startDate: Date
    let endDate: Date
    let asleepDuration: TimeInterval
    let inBedDuration: TimeInterval?
}

enum HealthHeartMetricKind: String, Equatable, Sendable, Codable {
    case restingHeartRate
    case heartRateVariabilitySDNN
}

struct HealthHeartMetric: Equatable, Sendable, Identifiable {
    let id: UUID
    let kind: HealthHeartMetricKind
    let date: Date
    let value: Double
    let unitSymbol: String
}

struct HealthBodyMassRecord: Equatable, Sendable, Identifiable {
    let id: UUID
    let date: Date
    let valueKg: Double
}
