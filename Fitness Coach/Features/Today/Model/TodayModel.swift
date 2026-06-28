//
//  TodayModel.swift
//  Fitness Coach
//
//  FitPilot AI — Today Mission Control status. Mutations route through TodayActionCoordinator (future).
//

import Combine
import Foundation

@MainActor
final class TodayModel: ObservableObject {

    @Published private(set) var viewState: TodayViewState = .loading

    private let dailyLogService: DailyLogService
    private let foodLogService: FoodLogService
    private let workoutLogService: WorkoutLogService
    private let weightLogService: WeightLogService
    private let reviewService: ReviewService
    private let userProfileService: UserProfileService

    private var activityContext: TodayActivityContext = .default

    init(
        dailyLogService: DailyLogService,
        foodLogService: FoodLogService,
        workoutLogService: WorkoutLogService,
        weightLogService: WeightLogService,
        reviewService: ReviewService,
        userProfileService: UserProfileService
    ) {
        self.dailyLogService = dailyLogService
        self.foodLogService = foodLogService
        self.workoutLogService = workoutLogService
        self.weightLogService = weightLogService
        self.reviewService = reviewService
        self.userProfileService = userProfileService
    }

    // MARK: Loading

    func loadToday(activityContext: TodayActivityContext = .default) async {
        self.activityContext = activityContext
        if !viewState.isLoaded {
            viewState = .loading
        }
        do {
            try loadDashboard()
        } catch ServiceError.missingUserProfile {
            viewState = .empty
        } catch {
            if !viewState.isLoaded {
                viewState = .error(TodayLoadErrorFormatting.message(for: error, isRefresh: false))
            }
        }
    }

    func refresh(activityContext: TodayActivityContext? = nil) async {
        if let activityContext {
            self.activityContext = activityContext
        }
        let previousState = viewState
        do {
            try loadDashboard()
        } catch ServiceError.missingUserProfile {
            viewState = .empty
        } catch {
            guard case .loaded = previousState else {
                viewState = .error(TodayLoadErrorFormatting.message(for: error, isRefresh: true))
                return
            }
        }
    }

    // MARK: State Building

    private func loadDashboard() throws {
        let dailyLog = try dailyLogService.getTodayLog()
        let foodEntries = try foodLogService.getFoodEntries(for: dailyLog.date)
        let workouts = try workoutLogService.getWorkouts(for: dailyLog.date)
        let latestWeight = dailyLog.weightKg == nil ? try weightLogService.getLatestWeight() : nil
        let dailyReview = try reviewService.getDailyReview(for: dailyLog.date)

        viewState = .loaded(
            try makeDashboardState(
                dailyLog: dailyLog,
                foodEntries: foodEntries,
                workouts: workouts,
                latestWeight: latestWeight,
                dailyReview: dailyReview
            )
        )
    }

    private func makeDashboardState(
        dailyLog: DailyLog,
        foodEntries: [FoodEntry],
        workouts: [WorkoutEntry],
        latestWeight: WeightEntry?,
        dailyReview: DailyReview?
    ) throws -> TodayDashboardState {
        let (calorieSummary, macroSummary, waterSummary) = TodayDashboardNutritionMapper.maps(from: dailyLog)

        let profile = try? userProfileService.getCurrentProfile()

        let displayWeight = dailyLog.weightKg ?? latestWeight?.weightKg
        let weightSummary = TodayWeightSummary(
            weightKg: displayWeight,
            displayText: displayWeight.map { String(format: "%.2f kg", $0) }
                ?? "Not logged today"
        )
        let weightLoggedToday = dailyLog.weightKg != nil
        let hasRecentWeight = latestWeight != nil || profile?.currentWeightKg != nil

        let workoutSummary = TodayWorkoutSummary(
            workoutCaloriesBurned: dailyLog.workoutCaloriesBurned,
            workoutCount: workouts.count,
            hasWorkout: !workouts.isEmpty
        )

        let trainingFrequency = profile?.trainingFrequencyPerWeek ?? 0
        let (streaks, weekLoggedDays) = try buildMomentumMetrics(asOf: dailyLog.date)
        let hasPriorFoodLogs = try hasPriorFoodLogs(before: dailyLog.date)
        let dailyBrief = DailyBriefBuilder.todayBrief(
            profile: profile,
            caloriesRemaining: calorieSummary.remaining,
            proteinRemaining: macroSummary.protein.remaining,
            waterRemainingMl: waterSummary.remainingMl,
            hasWorkoutToday: workoutSummary.hasWorkout,
            trainingFrequency: trainingFrequency
        )

        return TodayMissionControlStateBuilder.build(
            from: TodayMissionControlInputs(
                date: dailyLog.date,
                calorieSummary: calorieSummary,
                macroSummary: macroSummary,
                waterSummary: waterSummary,
                weightSummary: weightSummary,
                weightLoggedToday: weightLoggedToday,
                hasRecentWeight: hasRecentWeight,
                workoutSummary: workoutSummary,
                foodEntries: foodEntries,
                hasPriorFoodLogs: hasPriorFoodLogs,
                streaks: streaks,
                weekLoggedDays: weekLoggedDays,
                dailyBrief: dailyBrief,
                dailyReview: dailyReview,
                goalWeightKg: profile?.goalWeightKg,
                profileWeightKg: profile?.currentWeightKg,
                latestWeightKg: displayWeight,
                userName: profile?.name,
                activityContext: activityContext,
                stepGoalAssumption: profile.flatMap { $0.averageSteps > 0 ? $0.averageSteps : nil },
                trainingFrequencyPerWeek: profile.flatMap { $0.trainingFrequencyPerWeek > 0 ? $0.trainingFrequencyPerWeek : nil }
            )
        )
    }

    private func buildMomentumMetrics(asOf date: Date) throws -> (StreakSummary, Int) {
        let startDate = Calendar.current.date(byAdding: .day, value: -90, to: date) ?? date
        let logs = try dailyLogService.getLogs(from: startDate, to: date)
        let workouts = try workoutLogService.getWorkoutHistory(days: 90)
        let workoutDates = Set(workouts.map { Calendar.current.startOfDay(for: $0.createdAt) })
        let streaks = StreakCalculator.calculate(
            logs: logs,
            workoutDates: workoutDates,
            asOf: date
        )
        let weekLoggedDays = StreakCalculator.loggedDaysInRollingWindow(
            logs: logs,
            asOf: date
        )
        return (streaks, weekLoggedDays)
    }

    private func hasPriorFoodLogs(before date: Date) throws -> Bool {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: date)
        guard let lookbackStart = calendar.date(byAdding: .day, value: -365, to: todayStart) else {
            return false
        }
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: todayStart) else {
            return false
        }

        let logs = try dailyLogService.getLogs(from: lookbackStart, to: yesterday)
        return logs.contains { log in
            calendar.startOfDay(for: log.date) < todayStart && log.totals.calories > 0
        }
    }
}
