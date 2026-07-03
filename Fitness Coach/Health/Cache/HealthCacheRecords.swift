//
//  HealthCacheRecords.swift
//  Fitness Coach
//
//  Forma — Cache-layer aliases for normalized health domain records.
//

import Foundation

typealias WorkoutRecord = NormalizedWorkout
typealias SleepRecord = NormalizedSleepRecord
typealias HeartMetricRecord = NormalizedHeartMetric
typealias BodyMassRecord = NormalizedBodyMass

struct HealthCachedDayFile: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let date: Date
    let cachedAt: Date
    let dailyMetrics: DailyHealthMetrics
    let workouts: [WorkoutRecord]
    let sleepRecords: [SleepRecord]
    let heartMetrics: [HeartMetricRecord]
    let bodyMassRecords: [BodyMassRecord]

    init(
        schemaVersion: Int = HealthCachePolicy.schemaVersion,
        date: Date,
        cachedAt: Date,
        bundle: HealthNormalizedDayBundle
    ) {
        self.schemaVersion = schemaVersion
        self.date = date
        self.cachedAt = cachedAt
        self.dailyMetrics = bundle.dailyMetrics
        self.workouts = bundle.workouts
        self.sleepRecords = bundle.sleepRecords
        self.heartMetrics = bundle.heartMetrics
        self.bodyMassRecords = bundle.bodyMassRecords
    }

    var bundle: HealthNormalizedDayBundle {
        HealthNormalizedDayBundle(
            dailyMetrics: dailyMetrics,
            workouts: workouts,
            sleepRecords: sleepRecords,
            heartMetrics: heartMetrics,
            bodyMassRecords: bodyMassRecords
        )
    }
}

enum HealthCacheAggregateKind: String, Codable, Sendable {
    case workouts
    case sleep
    case heart
    case bodyMass
}

struct HealthCacheMetadata: Codable, Equatable, Sendable {
    var schemaVersion: Int
    var userID: String
    var lastPrunedAt: Date?
    var lastUpdatedAt: Date?
    var workoutsIndexUpdatedAt: Date?
    var sleepIndexUpdatedAt: Date?
    var heartIndexUpdatedAt: Date?
    var bodyMassIndexUpdatedAt: Date?

    static func initial(userID: String) -> HealthCacheMetadata {
        HealthCacheMetadata(
            schemaVersion: HealthCachePolicy.schemaVersion,
            userID: userID,
            lastPrunedAt: nil,
            lastUpdatedAt: nil
        )
    }
}

struct HealthCacheRecoveryFile: Codable, Equatable, Sendable {
    let date: Date
    let cachedAt: Date
    let summary: RecoverySummary
}

struct HealthIntelligenceSnapshotCacheEntry: Equatable, Sendable {
    let snapshot: HealthIntelligenceSnapshot
    let cachedAt: Date
}

struct HealthCacheSnapshotFile: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let date: Date
    let cachedAt: Date
    let snapshot: HealthIntelligenceSnapshot

    init(
        schemaVersion: Int = HealthCachePolicy.schemaVersion,
        date: Date,
        cachedAt: Date,
        snapshot: HealthIntelligenceSnapshot
    ) {
        self.schemaVersion = schemaVersion
        self.date = date
        self.cachedAt = cachedAt
        self.snapshot = snapshot
    }
}

struct HealthCacheWeeklyReviewFile: Codable, Equatable, Sendable {
    let weekStartDate: Date
    let cachedAt: Date
    let review: WeeklyHealthReview
}
