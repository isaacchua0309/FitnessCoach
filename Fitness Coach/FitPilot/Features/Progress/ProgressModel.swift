//
//  ProgressModel.swift
//  Fitness Coach
//
//  FitPilot AI — Feature model for read-only progress analytics.
//
//  ProgressModel reads through services and uses deterministic calculators. It
//  does not access SwiftData directly, call AI, or mutate logs.
//

import Combine
import Foundation

@MainActor
final class ProgressModel: ObservableObject {

    @Published private(set) var viewState: ProgressViewState = .loading
    @Published private(set) var selectedRangeDays: Int = 28

    private let dailyLogService: DailyLogService
    private let weightLogService: WeightLogService
    private let workoutLogService: WorkoutLogService
    private let userProfileService: UserProfileService

    private let supportedRanges = [7, 14, 28]

    init(
        dailyLogService: DailyLogService,
        weightLogService: WeightLogService,
        workoutLogService: WorkoutLogService,
        userProfileService: UserProfileService
    ) {
        self.dailyLogService = dailyLogService
        self.weightLogService = weightLogService
        self.workoutLogService = workoutLogService
        self.userProfileService = userProfileService
    }

    // MARK: Loading

    func loadProgress() async {
        viewState = .loading
        await refresh()
    }

    func refresh() async {
        do {
            let state = try makeDashboardState(rangeDays: selectedRangeDays)
            viewState = state.hasEnoughData ? .loaded(state) : .empty
        } catch {
            viewState = .error("Could not load progress trends.")
        }
    }

    func selectRange(days: Int) async {
        selectedRangeDays = supportedRanges.contains(days) ? days : 28
        await refresh()
    }

    // MARK: State Building

    private func makeDashboardState(rangeDays: Int) throws -> ProgressDashboardState {
        let endDate = Date()
        let startDate = Calendar.current.date(
            byAdding: .day,
            value: -rangeDays + 1,
            to: endDate
        ) ?? endDate

        let logs = try dailyLogService.getLogs(from: startDate, to: endDate)
        let weights = try weightLogService.getWeightEntries(from: startDate, to: endDate)
        let workouts = try workoutLogService.getWorkoutHistory(days: rangeDays)
            .filter { $0.createdAt >= startDate && $0.createdAt <= endDate }
        let profile = try userProfileService.getCurrentProfile()

        let weightTrend = WeightTrendCalculator.trend(from: weights, endingOn: endDate)
        let weightSummary = ProgressWeightSummary(
            latestWeightKg: weightTrend.latestWeightKg,
            sevenDayAverageKg: weightTrend.sevenDayAverageKg,
            previousSevenDayAverageKg: weightTrend.previousSevenDayAverageKg,
            changeKg: weightTrend.changeKg ?? WeightTrendCalculator.weightChange(from: weights),
            direction: weightTrend.direction,
            hasSuddenSpike: weightTrend.hasSuddenSpike
        )

        let maintenanceEstimate = MaintenanceCalculator.estimateMaintenance(
            logs: logs,
            weights: weights
        )

        let goalProjection = profile.map {
            ProgressProjectionCalculator.projection(
                weights: weights,
                goalWeightKg: $0.goalWeightKg,
                asOf: endDate
            )
        }

        return ProgressDashboardState(
            selectedRangeDays: rangeDays,
            weightSummary: weightSummary,
            weightChartPoints: makeWeightChartPoints(weights: weights),
            nutritionSummary: makeNutritionSummary(logs: logs),
            waterSummary: makeWaterSummary(logs: logs),
            maintenanceEstimate: maintenanceEstimate,
            goalProjection: goalProjection,
            workoutSummary: makeWorkoutSummary(workouts: workouts, rangeDays: rangeDays),
            hasEnoughData: !logs.isEmpty || !weights.isEmpty
        )
    }

    private func makeWeightChartPoints(weights: [WeightEntry]) -> [WeightChartPoint] {
        let sorted = weights.sorted { $0.date < $1.date }
        return sorted.map { entry in
            WeightChartPoint(
                date: entry.date,
                weightKg: entry.weightKg,
                sevenDayAverageKg: WeightTrendCalculator.averageWeight(
                    from: sorted,
                    days: 7,
                    endingOn: entry.date
                )
            )
        }
    }

    private func makeNutritionSummary(logs: [DailyLog]) -> ProgressNutritionSummary {
        guard !logs.isEmpty else {
            return ProgressNutritionSummary(
                loggedDays: 0,
                averageCalories: nil,
                averageProtein: nil,
                averageCarbs: nil,
                averageFat: nil,
                averageFiber: nil
            )
        }

        let count = Double(logs.count)
        let totalCalories = logs.reduce(0) { $0 + $1.totals.calories }
        let totalProtein = logs.reduce(0.0) { $0 + $1.totals.protein }
        let totalCarbs = logs.reduce(0.0) { $0 + $1.totals.carbs }
        let totalFat = logs.reduce(0.0) { $0 + $1.totals.fat }
        let fiberValues = logs.compactMap(\.totals.fiber)

        return ProgressNutritionSummary(
            loggedDays: logs.count,
            averageCalories: Int((Double(totalCalories) / count).rounded()),
            averageProtein: totalProtein / count,
            averageCarbs: totalCarbs / count,
            averageFat: totalFat / count,
            averageFiber: average(fiberValues)
        )
    }

    private func makeWaterSummary(logs: [DailyLog]) -> ProgressWaterSummary {
        guard !logs.isEmpty else {
            return ProgressWaterSummary(
                loggedDays: 0,
                averageWaterMl: nil,
                averageWaterTargetMl: nil,
                consistencyPercent: nil
            )
        }

        let totalWater = logs.reduce(0) { $0 + $1.waterConsumedMl }
        let totalTargets = logs.reduce(0) { $0 + $1.targets.waterTargetMl }
        let eligible = logs.filter { $0.targets.waterTargetMl > 0 }
        let consistentDays = eligible.filter {
            Double($0.waterConsumedMl) >= Double($0.targets.waterTargetMl) * 0.8
        }.count

        let consistency: Double? = eligible.isEmpty
            ? nil
            : Double(consistentDays) / Double(eligible.count)

        return ProgressWaterSummary(
            loggedDays: logs.count,
            averageWaterMl: Int((Double(totalWater) / Double(logs.count)).rounded()),
            averageWaterTargetMl: Int((Double(totalTargets) / Double(logs.count)).rounded()),
            consistencyPercent: consistency
        )
    }

    private func makeWorkoutSummary(
        workouts: [WorkoutEntry],
        rangeDays: Int
    ) -> ProgressWorkoutSummary? {
        guard !workouts.isEmpty else { return nil }

        let totalCalories = workouts.reduce(0) { $0 + ($1.estimatedCaloriesBurned ?? 0) }
        let weeks = max(Double(rangeDays) / 7.0, 1.0)

        return ProgressWorkoutSummary(
            workoutCount: workouts.count,
            totalEstimatedCaloriesBurned: totalCalories,
            averageWorkoutsPerWeek: Double(workouts.count) / weeks
        )
    }

    private func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}
