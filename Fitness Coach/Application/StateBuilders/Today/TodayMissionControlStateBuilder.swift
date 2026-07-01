//
//  TodayMissionControlStateBuilder.swift
//  Fitness Coach
//
//  Assembles Mission Control section state from nutrition summaries and profile context.
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
    var streaks: StreakSummary
    var weekLoggedDays: Int
    var dailyBrief: TodayDailyBrief
    var dailyReview: DailyReview?
    var goalWeightKg: Double?
    var profileWeightKg: Double?
    var latestWeightKg: Double?
    var userName: String?
    var activityContext: TodayActivityContext
    var stepGoalAssumption: Int?
    var trainingFrequencyPerWeek: Int?
}

enum TodayMissionControlStateBuilder {

    static func build(from inputs: TodayMissionControlInputs) -> TodayDashboardState {
        let focusMessage = TodayFocusBuilder.focus(
            proteinProgress: inputs.macroSummary.protein.progress,
            waterProgress: inputs.waterSummary.progress,
            weightLogged: inputs.weightSummary.weightKg != nil,
            hasWorkout: inputs.workoutSummary.hasWorkout,
            trainingIntegration: inputs.activityContext.trainingIntegration,
            trainingDataSource: inputs.activityContext.trainingDataSource
        )

        let mission = buildMission(
            calorieSummary: inputs.calorieSummary,
            macroSummary: inputs.macroSummary,
            waterSummary: inputs.waterSummary,
            weightSummary: inputs.weightSummary,
            foodEntries: inputs.foodEntries,
            goalWeightKg: inputs.goalWeightKg,
            latestWeightKg: inputs.latestWeightKg,
            profileWeightKg: inputs.profileWeightKg,
            focusMessage: focusMessage
        )

        return TodayDashboardState(
            date: inputs.date,
            hasDailyLog: true,
            emptyContext: buildEmptyContext(from: inputs),
            mission: mission,
            goalConnection: buildGoalConnection(from: inputs),
            nextBestAction: buildNextBestAction(from: inputs),
            meals: buildMeals(from: inputs.foodEntries),
            activity: buildActivity(from: inputs),
            macroBalance: MacroBalanceState(
                macroSummary: inputs.macroSummary,
                waterSummary: inputs.waterSummary
            ),
            momentum: buildMomentum(
                streaks: inputs.streaks,
                weekLoggedDays: inputs.weekLoggedDays
            ),
            dailyScorecard: buildDailyScorecard(from: inputs),
            dailySummary: DailySummaryState(
                greeting: inputs.dailyBrief.greeting,
                priorities: inputs.dailyBrief.priorities,
                userName: inputs.userName,
                dailyReview: inputs.dailyReview
            ),
            aiCoachTip: TodayCoachTipBuilder.build(
                from: TodayCoachTipInput(
                    date: inputs.date,
                    calendar: .current,
                    calorieSummary: inputs.calorieSummary,
                    macroSummary: inputs.macroSummary,
                    waterSummary: inputs.waterSummary,
                    foodEntries: inputs.foodEntries
                )
            )
        )
    }

    // MARK: - Mission

    static func buildMission(
        calorieSummary: CalorieSummary,
        macroSummary: MacroSummary,
        waterSummary: WaterSummary,
        weightSummary: TodayWeightSummary,
        foodEntries: [FoodEntry],
        goalWeightKg: Double?,
        latestWeightKg: Double?,
        profileWeightKg: Double?,
        focusMessage: String
    ) -> TodayMissionState {
        TodayMissionState(
            status: missionStatus(
                calorieSummary: calorieSummary,
                macroSummary: macroSummary,
                waterSummary: waterSummary,
                foodEntries: foodEntries
            ),
            calorieSummary: calorieSummary,
            weightSummary: weightSummary,
            goalProgress: goalProgress(
                latestWeightKg: latestWeightKg,
                profileWeightKg: profileWeightKg,
                goalWeightKg: goalWeightKg
            ),
            focusMessage: focusMessage,
            proteinRemainingGrams: max(macroSummary.protein.remaining, 0)
        )
    }

    static func missionStatus(
        calorieSummary: CalorieSummary,
        macroSummary: MacroSummary,
        waterSummary: WaterSummary,
        foodEntries: [FoodEntry]
    ) -> TodayMissionStatus {
        if calorieSummary.isOverTarget {
            return .overBudget
        }

        let proteinLow = macroSummary.protein.progress < TodayFocusBuilder.proteinOnTrackThreshold
        let waterLow = waterSummary.progress < TodayFocusBuilder.waterOnTrackThreshold
        if foodEntries.isEmpty || proteinLow || waterLow {
            return .needsFocus
        }

        return .onTrack
    }

    static func goalProgress(
        latestWeightKg: Double?,
        profileWeightKg: Double?,
        goalWeightKg: Double?
    ) -> TodayGoalProgressState? {
        guard let currentWeightKg = TodayGoalConnectionFormatting.resolvedCurrentWeight(
            latestWeightKg: latestWeightKg,
            profileWeightKg: profileWeightKg
        ),
              let goalWeightKg,
              goalWeightKg > 0 else {
            return nil
        }

        let direction = JourneyGoalDirection.resolve(
            startWeightKg: currentWeightKg,
            goalWeightKg: goalWeightKg
        )
        let kgToGo = abs(currentWeightKg - goalWeightKg)
        guard direction != .maintain, kgToGo > TodayGoalConnectionFormatting.maintainToleranceKg else {
            return nil
        }

        return TodayGoalProgressState(
            currentWeightKg: currentWeightKg,
            goalWeightKg: goalWeightKg,
            kgToGo: kgToGo,
            direction: direction
        )
    }

    static func buildGoalConnection(from inputs: TodayMissionControlInputs) -> TodayGoalConnectionState? {
        TodayGoalConnectionFormatting.displayModel(
            for: TodayGoalConnectionInput(
                latestWeightKg: inputs.latestWeightKg,
                profileWeightKg: inputs.profileWeightKg,
                goalWeightKg: inputs.goalWeightKg
            )
        )
    }

    // MARK: - Next Best Action

    static func buildNextBestAction(from inputs: TodayMissionControlInputs) -> NextBestActionState {
        NextBestActionEngine.resolve(
            NextBestActionInput(
                date: inputs.date,
                calendar: .current,
                foodEntries: inputs.foodEntries,
                proteinProgress: inputs.macroSummary.protein,
                waterProgress: inputs.waterSummary.progress,
                weightLoggedToday: inputs.weightLoggedToday,
                hasRecentWeight: inputs.hasRecentWeight,
                activityContext: inputs.activityContext,
                hasDailyReview: inputs.dailyReview != nil
            )
        )
    }

    // MARK: - Meals

    static func buildMeals(from entries: [FoodEntry]) -> MealStatusState {
        MealStatusState(
            entries: entries,
            entryCount: entries.count,
            isEmpty: entries.isEmpty
        )
    }

    // MARK: - Activity

    static func buildActivity(from inputs: TodayMissionControlInputs) -> ActivityTodayState {
        let context = inputs.activityContext
        let displayLine = activityDisplayLine(
            context: context,
            legacyWorkoutSummary: inputs.workoutSummary
        )
        let showsConnectCTA = context.trainingDataSource == .appleHealth
            && context.trainingIntegration.showsConnectionGate

        return ActivityTodayState(
            legacyWorkoutSummary: inputs.workoutSummary,
            trainingIntegration: context.trainingIntegration,
            trainingDataSource: context.trainingDataSource,
            appleHealthWorkoutCount: context.appleHealthWorkoutCount,
            stepsToday: context.stepsToday,
            weeklyWorkoutCount: context.weeklyWorkoutCount,
            stepGoalAssumption: inputs.stepGoalAssumption,
            trainingFrequencyPerWeek: inputs.trainingFrequencyPerWeek,
            displayLine: displayLine,
            showsConnectCTA: showsConnectCTA
        )
    }

    static func activityDisplayLine(
        context: TodayActivityContext,
        legacyWorkoutSummary: TodayWorkoutSummary
    ) -> String {
        switch context.trainingDataSource {
        case .appleHealth:
            if context.trainingIntegration.showsConnectionGate {
                switch context.trainingIntegration {
                case .denied, .failed:
                    return FormaProductCopy.Today.actionManageHealthAccess
                case .notConnected, .unavailable, .requestingPermission, .connected:
                    return FormaProductCopy.Training.Integration.connectAppleHealth
                }
            }

            if let count = context.appleHealthWorkoutCount, count > 0 {
                return FormaProductCopy.Today.workoutsToday(count)
            }

            return FormaProductCopy.Today.statusNoAppleHealthWorkoutToday

        case .unavailable:
            if legacyWorkoutSummary.hasWorkout {
                return FormaProductCopy.Today.statusWorkoutRecorded
            }
            return FormaProductCopy.Today.statusNoWorkoutToday
        }
    }

    // MARK: - Momentum

    static func buildMomentum(
        streaks: StreakSummary,
        weekLoggedDays: Int
    ) -> TodayMomentumState {
        TodayMomentumState(
            streaks: streaks,
            weekLoggedDays: weekLoggedDays
        )
    }

    static func buildEmptyContext(from inputs: TodayMissionControlInputs) -> TodayDashboardEmptyContext {
        TodayDashboardEmptyContext(
            mealsEmptyKind: TodayEmptyStateFormatting.mealsEmptyKind(
                mealsEmpty: inputs.foodEntries.isEmpty,
                hasPriorFoodLogs: inputs.hasPriorFoodLogs
            ),
            showsWeightReminder: TodayEmptyStateFormatting.shouldShowWeightReminder(
                weightLoggedToday: inputs.weightLoggedToday,
                hasRecentWeight: inputs.hasRecentWeight
            )
        )
    }

    static func buildDailyScorecard(from inputs: TodayMissionControlInputs) -> TodayDailySummaryScorecardState {
        TodayDailySummaryScoring.scorecard(
            from: TodayDailySummaryScoreInput(
                calorieSummary: inputs.calorieSummary,
                macroSummary: inputs.macroSummary,
                waterSummary: inputs.waterSummary,
                activity: buildActivity(from: inputs)
            )
        )
    }

    // MARK: - Coach Tip

    // Tip generation lives in TodayCoachTipBuilder (deterministic, no API).
}
