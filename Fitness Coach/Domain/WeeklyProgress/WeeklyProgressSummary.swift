//
//  WeeklyProgressSummary.swift
//  Fitness Coach
//
//  Forma — Canonical weekly progress summary for Journey, Plan, Today, and analytics.
//

import Foundation

// MARK: - Verdict & actions

enum WeeklyProgressVerdict: String, Codable, Equatable {
    case notEnoughData
    case onTrack
    case likelyTooAggressive
    case likelyTooSlow
    case noisyButLikelyOkay
    case needsConsistencyFirst
    case maintaining
    case unclear
}

enum WeeklyProgressNextAction: String, Codable, Equatable {
    case keepLogging
    case holdSteady
    case reviewPlan
    case improveLoggingConsistency
    case logWeightMoreOften
    case focusProtein
    case focusWater
    case reviewDailySummary
}

// MARK: - Week window

enum WeeklyProgressWeekWindowKind: String, Codable, Equatable {
    /// Most recent fully completed calendar week (preferred for v1 ritual).
    case completedCalendarWeek
    /// Rolling seven-day window ending on the reference date.
    case rollingSevenDays
}

struct WeeklyProgressWeekRange: Equatable {
    let kind: WeeklyProgressWeekWindowKind
    let startDate: Date
    let endDate: Date
    let totalDays: Int
}

// MARK: - Summary

struct WeeklyProgressSummary: Equatable {
    let id: String
    let startDate: Date
    let endDate: Date
    let generatedAt: Date

    let confidence: WeeklyProgressConfidenceLevel
    let verdict: WeeklyProgressVerdict
    let nextAction: WeeklyProgressNextAction

    let maintenanceEstimate: MaintenanceEstimate

    let foodLoggedDays: Int
    let totalDays: Int
    let averageDailyCalories: Int?
    let averageDailyProteinGrams: Int?
    let proteinHitDays: Int
    let calorieTargetHitDays: Int
    let waterTargetHitDays: Int
    let trainingDays: Int?

    let startingWeightKg: Double?
    let endingWeightKg: Double?
    let weightChangeKg: Double?
    let weeklyWeightChangeKg: Double?
    let hasSuddenSpike: Bool

    let headline: String
    let summary: String
    let primaryInsight: String
    let nextActionTitle: String
    let nextActionSubtitle: String
    let caveats: [String]
}

// MARK: - Input

struct WeeklyProgressSummaryInput: Equatable {
    let referenceDate: Date
    let calendar: Calendar
    let dailyLogs: [DailyLog]
    let weightEntries: [WeightEntry]
    let healthWorkoutDayStarts: Set<Date>
    let staticTDEEKcal: Double?
    let calorieTargetKcal: Double?
    let goalWeightKg: Double?
    let currentWeightKg: Double?
    let generatedAt: Date
}
