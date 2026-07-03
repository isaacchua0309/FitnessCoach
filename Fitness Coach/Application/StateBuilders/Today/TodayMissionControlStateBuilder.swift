//
//  TodayMissionControlStateBuilder.swift
//  Fitness Coach
//
//  Assembles Today dashboard state from nutrition summaries and profile context.
//

import Foundation

struct TodayMissionControlInputs: Equatable {
    var date: Date
    var calorieSummary: CalorieSummary
    var macroSummary: MacroSummary
    var waterSummary: WaterSummary
    var weightSummary: TodayWeightSummary
    var weightLoggedToday: Bool
    var hasRecentWeight: Bool
    var workoutSummary: TodayWorkoutSummary
    var foodEntries: [FoodEntry]
    var hasPriorFoodLogs: Bool
    var dailyReview: DailyReview?
    var goalWeightKg: Double?
    var profileWeightKg: Double?
    var latestWeightKg: Double?
    var activityContext: TodayActivityContext
    var stepGoalAssumption: Int?
}

enum TodayMissionControlStateBuilder {

    static func build(from inputs: TodayMissionControlInputs) -> TodayDashboardState {
        TodayPresentationBuilder.dashboard(from: inputs)
    }
}
