//
//  DailyHealthMetrics.swift
//  Fitness Coach
//
//  Forma — Domain models produced by HealthSampleNormalizer.
//

import Foundation

struct DailyHealthMetrics: Equatable, Sendable {
    let date: Date
    let steps: Int
    let activeEnergyKcal: Double
    let exerciseMinutes: Double

    static let zero = DailyHealthMetrics(
        date: .distantPast,
        steps: 0,
        activeEnergyKcal: 0,
        exerciseMinutes: 0
    )

    static func empty(for date: Date) -> DailyHealthMetrics {
        DailyHealthMetrics(
            date: date,
            steps: 0,
            activeEnergyKcal: 0,
            exerciseMinutes: 0
        )
    }
}

enum FormaWorkoutCategory: String, CaseIterable, Codable, Sendable, Hashable {
    case strength
    case running
    case walking
    case cycling
    case swimming
    case yoga
    case hiit
    case other
}

struct NormalizedWorkout: Equatable, Sendable, Identifiable {
    let id: UUID
    let category: FormaWorkoutCategory
    let activityLabel: String
    let startDate: Date
    let endDate: Date
    let durationMinutes: Int
    let activeEnergyKcal: Double
    let sourceName: String?
}

struct NormalizedSleepRecord: Equatable, Sendable, Identifiable {
    let id: UUID
    let startDate: Date
    let endDate: Date
    let asleepMinutes: Double
    let inBedMinutes: Double?
}

struct NormalizedHeartMetric: Equatable, Sendable, Identifiable {
    let id: UUID
    let kind: HealthHeartMetricKind
    let date: Date
    let value: Double
    let unitSymbol: String
}

struct NormalizedBodyMass: Equatable, Sendable, Identifiable {
    let id: UUID
    let date: Date
    let valueKg: Double
}

struct HealthRawDayInput: Equatable, Sendable {
    let dailyMetrics: HealthDailyMetrics
    let workouts: [HealthFetchedWorkout]
    let sleepRecords: [HealthSleepRecord]
    let heartMetrics: [HealthHeartMetric]
    let bodyMassRecords: [HealthBodyMassRecord]
}

struct HealthNormalizedDayBundle: Equatable, Sendable {
    let dailyMetrics: DailyHealthMetrics
    let workouts: [NormalizedWorkout]
    let sleepRecords: [NormalizedSleepRecord]
    let heartMetrics: [NormalizedHeartMetric]
    let bodyMassRecords: [NormalizedBodyMass]
}
