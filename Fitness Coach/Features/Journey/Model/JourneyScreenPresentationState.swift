//
//  JourneyScreenPresentationState.swift
//  Fitness Coach
//
//  Forma — Single source of truth for Journey tab presentation (phase, week, streaks,
//  stats, unlocks, next action, copy, sync, and story ordering).
//

import Foundation

// MARK: - Root

/// Canonical Journey screen payload consumed by section views. Built once per dashboard load.
struct JourneyScreenPresentationState: Equatable, Sendable {
    var phase: JourneyPhasePresentationState
    var streaks: JourneyStreakBreakdownState
    var weekly: JourneyWeeklyPresentationState
    var unlocks: JourneyUnlockPresentationState
    var nextBestAction: JourneyNextBestActionState
    var copy: JourneyCopyPresentationState
    var sync: JourneySyncPresentationState
    var story: JourneyStoryPresentationState
}

// MARK: - Phase

struct JourneyPhasePresentationState: Equatable, Sendable {
    /// 1-based journey week since the user's first meaningful log or profile creation.
    var weekNumber: Int
    var chapterTitle: String
    var chapterSubtitle: String
    var chapterProgressPercent: Double
    var nextChapterAction: String?
}

// MARK: - Streaks

enum JourneyStreakKind: Equatable, Sendable {
    case mealLogging
    case checkIn
    case activity
}

struct JourneyStreakBreakdownState: Equatable, Sendable {
    /// Consecutive days with at least one meal logged (`calories > 0`). Zero when no meals.
    var mealLoggingStreakDays: Int
    /// Consecutive days with any app check-in (meal, water, or weight).
    var checkInStreakDays: Int
    /// Consecutive days with a logged or HealthKit workout.
    var activityStreakDays: Int
    var longestMealLoggingStreakDays: Int
    var longestCheckInStreakDays: Int
    var isTodayCheckedIn: Bool
    var isTodayMealLogged: Bool

    /// When false, UI must not show a meal streak label.
    var showsMealStreak: Bool { mealLoggingStreakDays > 0 }

    /// When false, UI must not show a check-in streak label.
    var showsCheckInStreak: Bool { checkInStreakDays > 0 }

    /// Primary streak surfaced in the momentum strip (prefers meal logging when active).
    var primaryMomentumKind: JourneyStreakKind
    var primaryMomentumDays: Int
    var primaryMomentumLabel: String
    var momentumDetail: String?
    var keepStreakAliveCopy: String?
}

// MARK: - Weekly

struct JourneyWeeklyPresentationState: Equatable, Sendable {
    var weekRange: WeeklyProgressWeekRange
    var dateRangeText: String
    var weekTitle: String
    var stats: JourneyWeeklyStatsState
    var confidence: JourneyWeeklyConfidencePresentationState
}

struct JourneyWeeklyStatsState: Equatable, Sendable {
    var mealsLogged: Int
    var mealLoggingDays: Int
    var proteinLoggingDays: Int
    var waterLoggingDays: Int
    var weighIns: Int
    var workouts: Int
    var averageSteps: Int?
    var recoveryAvailability: JourneyRecoveryAvailabilityState
}

enum JourneyRecoveryAvailabilityState: Equatable, Sendable {
    case unavailable
    case partial(daysWithSignals: Int, requiredDays: Int)
    case available
}

struct JourneyWeeklyConfidencePresentationState: Equatable, Sendable {
    var level: WeeklyProgressConfidenceLevel
    var label: String
    var accessibilityLabel: String
}

// MARK: - Unlocks

struct JourneyUnlockPresentationState: Equatable, Sendable {
    var projection: Bool
    var maintenanceEstimate: Bool
    var weightTrend: Bool
    var weeklyReview: Bool
    var nutritionInsight: Bool
    var recoveryBaseline: Bool
}

// MARK: - Next best action

enum JourneyNextBestActionKind: Equatable, Sendable {
    case logFirstMeal
    case logMealsConsistently
    case logWeightMoreOften
    case completeFirstWorkout
    case syncRecoveryData
    case keepStreakGoing
}

struct JourneyNextBestActionState: Equatable, Sendable {
    var kind: JourneyNextBestActionKind
    var title: String
    var detail: String?
    var accessibilityLabel: String
}

// MARK: - Copy policy

struct JourneyInsightEmptyState: Equatable, Sendable {
    /// What is building, e.g. "Building your first trend".
    var headline: String
    /// What is needed to unlock, e.g. "Log 3 meals and 2 more weigh-ins…".
    var requirement: String
    /// Primary next action title.
    var nextActionTitle: String
    /// Supporting detail for the next action.
    var nextActionDetail: String?
    /// Progress toward unlock when available, e.g. "2/5 meal days".
    var progressLabel: String?
}

struct JourneyCopyPresentationState: Equatable, Sendable {
    /// When false, UI must not use “log a few more meals” phrasing.
    var allowsFewMoreMealsCopy: Bool
    var confidenceLabel: String
    var confidenceAccessibilityLabel: String
    var insufficientDataSummary: String?
    var emptyState: JourneyInsightEmptyState?
}

// MARK: - Sync

struct JourneySyncPresentationState: Equatable, Sendable {
    var showsHealthSyncNotice: Bool
    var healthSyncNotice: String?
}

// MARK: - Story

struct JourneyStoryPresentationState: Equatable, Sendable {
    /// Story events sorted for display. See `JourneyStoryPresentationBuilder.displayOrder`.
    var events: [JourneyStoryEvent]
}
