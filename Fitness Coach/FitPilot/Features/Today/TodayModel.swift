//
//  TodayModel.swift
//  Fitness Coach
//
//  FitPilot AI — Read-only Today status. All mutations happen in Coach.
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

    func loadToday() async {
        viewState = .loading
        do {
            try loadDashboard()
        } catch ServiceError.missingUserProfile {
            viewState = .empty
        } catch {
            viewState = .error(FormaProductCopy.Error.loadToday)
        }
    }

    func refresh() async {
        do {
            try loadDashboard()
        } catch ServiceError.missingUserProfile {
            viewState = .empty
        } catch {
            viewState = .error(FormaProductCopy.Error.refreshToday)
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
        let targets = MacroCalculator.macroTargets(from: dailyLog.targets)
        let remaining = MacroCalculator.remaining(targets: targets, totals: dailyLog.totals)

        let calorieSummary = CalorieSummary(
            consumed: dailyLog.totals.calories,
            target: targets.calories,
            remaining: remaining.calories,
            progress: MacroCalculator.calorieProgress(totals: dailyLog.totals, targets: targets),
            isOverTarget: MacroCalculator.isOverCalories(totals: dailyLog.totals, targets: targets)
        )

        let macroSummary = MacroSummary(
            protein: MacroProgress(
                consumed: dailyLog.totals.protein,
                target: targets.protein,
                remaining: remaining.protein,
                progress: MacroCalculator.proteinProgress(totals: dailyLog.totals, targets: targets)
            ),
            carbs: MacroProgress(
                consumed: dailyLog.totals.carbs,
                target: targets.carbs,
                remaining: remaining.carbs,
                progress: MacroCalculator.progress(consumed: dailyLog.totals.carbs, target: targets.carbs)
            ),
            fat: MacroProgress(
                consumed: dailyLog.totals.fat,
                target: targets.fat,
                remaining: remaining.fat,
                progress: MacroCalculator.progress(consumed: dailyLog.totals.fat, target: targets.fat)
            )
        )

        let waterSummary = WaterSummary(
            consumedMl: dailyLog.waterConsumedMl,
            targetMl: dailyLog.targets.waterTargetMl,
            remainingMl: WaterTargetCalculator.remainingMl(
                consumedMl: dailyLog.waterConsumedMl,
                targetMl: dailyLog.targets.waterTargetMl
            ),
            progress: WaterTargetCalculator.progress(
                consumedMl: dailyLog.waterConsumedMl,
                targetMl: dailyLog.targets.waterTargetMl
            )
        )

        let displayWeight = dailyLog.weightKg ?? latestWeight?.weightKg
        let weightSummary = TodayWeightSummary(
            weightKg: displayWeight,
            displayText: displayWeight.map { String(format: "%.2f kg", $0) }
                ?? "Not logged today"
        )

        let workoutSummary = TodayWorkoutSummary(
            workoutCaloriesBurned: dailyLog.workoutCaloriesBurned,
            workoutCount: workouts.count,
            hasWorkout: !workouts.isEmpty
        )

        let profile = try? userProfileService.getCurrentProfile()
        let streaks = try buildStreaks(asOf: dailyLog.date)
        let dailyBrief = DailyBriefBuilder.todayBrief(
            profile: profile,
            caloriesRemaining: remaining.calories,
            proteinRemaining: remaining.protein,
            waterRemainingMl: waterSummary.remainingMl,
            hasWorkoutToday: workoutSummary.hasWorkout,
            trainingFrequency: profile?.trainingFrequencyPerWeek ?? 0
        )

        return TodayDashboardState(
            date: dailyLog.date,
            calorieSummary: calorieSummary,
            macroSummary: macroSummary,
            waterSummary: waterSummary,
            weightSummary: weightSummary,
            stepsSummary: dailyLog.steps.map { StepsSummary(steps: $0) },
            workoutSummary: workoutSummary,
            foodEntries: foodEntries,
            hasDailyLog: true,
            dailyReview: dailyReview,
            coachingNote: dailyBrief.recommendation,
            dailyBrief: dailyBrief,
            streaks: streaks,
            userName: profile?.name
        )
    }

    private func buildStreaks(asOf date: Date) throws -> StreakSummary {
        let startDate = Calendar.current.date(byAdding: .day, value: -90, to: date) ?? date
        let logs = try dailyLogService.getLogs(from: startDate, to: date)
        let workouts = try workoutLogService.getWorkoutHistory(days: 90)
        let workoutDates = Set(workouts.map { Calendar.current.startOfDay(for: $0.createdAt) })
        return StreakCalculator.calculate(logs: logs, workoutDates: workoutDates, asOf: date)
    }
}
