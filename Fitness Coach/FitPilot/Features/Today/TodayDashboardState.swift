//
//  TodayDashboardState.swift
//  Fitness Coach
//
//  FitPilot AI — View state for the Today dashboard.
//
//  This is app-facing view state only. It contains no SwiftData entities and
//  performs no business calculations; values are produced by TodayModel using
//  services and calculators.
//

import Foundation

enum TodayViewState: Equatable {
    case loading
    case loaded(TodayDashboardState)
    case empty
    case error(String)
}

struct TodayDashboardState: Equatable {
    var date: Date
    var calorieSummary: CalorieSummary
    var macroSummary: MacroSummary
    var waterSummary: WaterSummary
    var weightSummary: TodayWeightSummary
    var stepsSummary: StepsSummary?
    var workoutSummary: TodayWorkoutSummary
    var foodEntries: [FoodEntry]
    var hasDailyLog: Bool
    var dailyReview: DailyReview?
    var coachingNote: String?
}

struct CalorieSummary: Equatable {
    var consumed: Int
    var target: Int
    var remaining: Int
    var progress: Double
    var isOverTarget: Bool
}

struct MacroSummary: Equatable {
    var protein: MacroProgress
    var carbs: MacroProgress
    var fat: MacroProgress
}

struct MacroProgress: Equatable {
    var consumed: Double
    var target: Double
    var remaining: Double
    var progress: Double
}

struct WaterSummary: Equatable {
    var consumedMl: Int
    var targetMl: Int
    var remainingMl: Int
    var progress: Double
}

struct TodayWeightSummary: Equatable {
    var weightKg: Double?
    var displayText: String
}

struct StepsSummary: Equatable {
    var steps: Int
}

struct TodayWorkoutSummary: Equatable {
    var workoutCaloriesBurned: Int
    var workoutCount: Int
    var hasWorkout: Bool
}
