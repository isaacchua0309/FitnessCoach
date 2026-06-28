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
    var streaks: StreakSummary
    var dailyBrief: TodayDailyBrief
    var dailyReview: DailyReview?
    var goalWeightKg: Double?
    var profileWeightKg: Double?
    var userName: String?
    var activityContext: TodayActivityContext
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
            profileWeightKg: inputs.profileWeightKg,
            focusMessage: focusMessage
        )

        return TodayDashboardState(
            date: inputs.date,
            hasDailyLog: true,
            mission: mission,
            nextBestAction: buildNextBestAction(from: inputs),
            meals: buildMeals(from: inputs.foodEntries),
            activity: buildActivity(from: inputs),
            macroBalance: MacroBalanceState(
                macroSummary: inputs.macroSummary,
                waterSummary: inputs.waterSummary
            ),
            momentum: buildMomentum(from: inputs.streaks),
            dailySummary: DailySummaryState(
                greeting: inputs.dailyBrief.greeting,
                priorities: inputs.dailyBrief.priorities,
                userName: inputs.userName,
                dailyReview: inputs.dailyReview
            ),
            aiCoachTip: buildCoachTip(from: inputs.dailyBrief, focusMessage: focusMessage)
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
        profileWeightKg: Double?,
        goalWeightKg: Double?
    ) -> TodayGoalProgressState? {
        guard let currentWeightKg = profileWeightKg,
              let goalWeightKg,
              currentWeightKg > 0,
              goalWeightKg > 0 else {
            return nil
        }

        let direction = JourneyGoalDirection.resolve(
            startWeightKg: currentWeightKg,
            goalWeightKg: goalWeightKg
        )
        let kgToGo = abs(currentWeightKg - goalWeightKg)
        guard direction != .maintain, kgToGo > 0.1 else { return nil }

        return TodayGoalProgressState(
            currentWeightKg: currentWeightKg,
            goalWeightKg: goalWeightKg,
            kgToGo: kgToGo,
            direction: direction
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

    static func buildMomentum(from streaks: StreakSummary) -> TodayMomentumState {
        var detailLines: [String] = []

        if streaks.proteinStreak > 0 {
            detailLines.append("\(streaks.proteinStreak)-day protein streak")
        }
        if streaks.hydrationStreak > 0 {
            detailLines.append("\(streaks.hydrationStreak)-day hydration streak")
        }
        if streaks.workoutStreak > 0 {
            detailLines.append("\(streaks.workoutStreak)-day workout streak")
        }

        let headline: String
        if streaks.loggingStreak > 0 {
            headline = streaks.loggingStreak == 1
                ? "1-day logging streak"
                : "\(streaks.loggingStreak)-day logging streak"
        } else {
            headline = "Start today's log to build momentum"
        }

        return TodayMomentumState(
            streaks: streaks,
            headline: headline,
            detailLines: detailLines
        )
    }

    // MARK: - Coach Tip

    static func buildCoachTip(
        from dailyBrief: TodayDailyBrief,
        focusMessage: String
    ) -> AICoachTipState {
        let message = dailyBrief.recommendation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? focusMessage
            : dailyBrief.recommendation

        return AICoachTipState(
            message: message,
            coachPrefill: coachPrefill(for: message)
        )
    }

    private static func coachPrefill(for message: String) -> String? {
        if message == FormaProductCopy.Today.focusProteinLow {
            return TodayCoachPrompt.logProtein
        }
        if message == FormaProductCopy.Today.focusWaterLow {
            return TodayCoachPrompt.logWater
        }
        return nil
    }
}
