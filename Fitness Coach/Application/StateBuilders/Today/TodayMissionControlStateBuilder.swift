//
//  TodayMissionControlStateBuilder.swift
//  Fitness Coach
//
//  Assembles Today dashboard state from nutrition summaries and profile context.
//

import Foundation

struct TodayYesterdayReviewInput: Equatable {
    var date: Date
    var review: DailyReview?
    var foodEntryCount: Int
    var waterConsumedMl: Int
    var workoutCaloriesBurned: Int
    var weightLogged: Bool
}

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
    var yesterdayReviewInput: TodayYesterdayReviewInput?
    var goalWeightKg: Double?
    var profileWeightKg: Double?
    var latestWeightKg: Double?
    var activityContext: TodayActivityContext
    var stepGoalAssumption: Int?
    var trainingFrequencyPerWeek: Int
}

enum TodayMissionControlStateBuilder {

    static func build(from inputs: TodayMissionControlInputs) -> TodayDashboardState {
        TodayPresentationBuilder.dashboard(from: inputs)
    }
}
