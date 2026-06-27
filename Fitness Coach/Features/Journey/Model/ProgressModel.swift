//
//  ProgressModel.swift
//  Fitness Coach
//
//  FitPilot AI — Read-only Journey transformation state.
//

import Combine
import Foundation

@MainActor
final class ProgressModel: ObservableObject {

    @Published private(set) var viewState: ProgressViewState = .loading
    @Published private(set) var selectedRangeDays: Int = 28

    private let dailyLogService: DailyLogService
    private let weightLogService: WeightLogService
    private let userProfileService: UserProfileService
    private let trainingInsightsStore: TrainingInsightsStore
    private let workoutReader: HealthKitWorkoutReading

    private let supportedRanges = [7, 14, 28]

    init(
        dailyLogService: DailyLogService,
        weightLogService: WeightLogService,
        workoutLogService: WorkoutLogService,
        userProfileService: UserProfileService,
        trainingInsightsStore: TrainingInsightsStore,
        workoutReader: HealthKitWorkoutReading? = nil
    ) {
        self.dailyLogService = dailyLogService
        self.weightLogService = weightLogService
        self.userProfileService = userProfileService
        self.trainingInsightsStore = trainingInsightsStore
        self.workoutReader = workoutReader ?? MockHealthKitWorkoutReader(workouts: [])
        _ = workoutLogService
    }

    // MARK: Loading

    func loadProgress() async {
        viewState = .loading
        await refresh()
    }

    func refresh() async {
        do {
            await trainingInsightsStore.refresh()
            let state = try await makeDashboardState(rangeDays: selectedRangeDays)
            viewState = state.hasProfile ? .loaded(state) : .empty
        } catch ServiceError.missingUserProfile {
            viewState = .empty
        } catch {
            viewState = .error(FormaProductCopy.Error.loadJourney)
        }
    }

    func selectRange(days: Int) async {
        selectedRangeDays = supportedRanges.contains(days) ? days : 28
        await refresh()
    }

    // MARK: State Building

    private func makeDashboardState(rangeDays: Int) async throws -> ProgressDashboardState {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -rangeDays + 1, to: endDate) ?? endDate
        let weekStart = calendar.date(byAdding: .day, value: -6, to: endDate) ?? endDate
        let prevWeekStart = calendar.date(byAdding: .day, value: -13, to: endDate) ?? endDate
        let prevWeekEnd = calendar.date(byAdding: .day, value: -7, to: endDate) ?? endDate
        let allTimeStart = calendar.date(byAdding: .day, value: -365, to: endDate) ?? endDate

        let logs = try dailyLogService.getLogs(from: startDate, to: endDate)
        let weekLogs = try dailyLogService.getLogs(from: weekStart, to: endDate)
        let previousWeekLogs = try dailyLogService.getLogs(from: prevWeekStart, to: prevWeekEnd)
        let maturityLogs = try dailyLogService.getLogs(from: allTimeStart, to: endDate)

        let weights = try weightLogService.getWeightEntries(from: startDate, to: endDate)
        let allWeights = try weightLogService.getWeightEntries(from: allTimeStart, to: endDate)

        let integrationState = trainingInsightsStore.integrationState
        let dataSource = trainingInsightsStore.dataSource

        let rangeHealthWorkouts = try await fetchHealthWorkouts(from: startDate, to: endDate)
        let weekHealthWorkouts = try await fetchHealthWorkouts(from: weekStart, to: endDate)
        let allHealthWorkouts = try await fetchHealthWorkouts(from: allTimeStart, to: endDate)

        let weeklyTraining = JourneyTrainingSummaryBuilder.weeklyTrainingStatus(
            integrationState: integrationState,
            dataSource: dataSource,
            weekWorkouts: weekHealthWorkouts,
            asOf: endDate,
            calendar: calendar
        )

        let profile = try userProfileService.getCurrentProfile()

        let weightTrend = WeightTrendCalculator.trend(from: weights, endingOn: endDate)
        let weightSummary = ProgressWeightSummary(
            latestWeightKg: weightTrend.latestWeightKg,
            changeKg: weightTrend.changeKg ?? WeightTrendCalculator.weightChange(from: weights),
            direction: weightTrend.direction,
            hasSuddenSpike: weightTrend.hasSuddenSpike
        )

        let currentWeight = weightSummary.latestWeightKg ?? profile?.currentWeightKg
        let nutritionSummary = makeNutritionSummary(logs: logs)
        let waterSummary = makeWaterSummary(logs: logs)
        let workoutSummary = JourneyTrainingSummaryBuilder.workoutAnalytics(
            integrationState: integrationState,
            dataSource: dataSource,
            workouts: rangeHealthWorkouts,
            rangeDays: rangeDays,
            calendar: calendar
        )

        let goalProjection = profile.map {
            ProgressProjectionCalculator.projection(
                weights: allWeights,
                goalWeightKg: $0.goalWeightKg,
                asOf: endDate
            )
        }

        let loggedDays = meaningfulLoggedDays(from: maturityLogs, weights: allWeights)
        let journeyStart = JourneyStateBuilder.journeyStartDate(
            profile: profile,
            logs: maturityLogs,
            weights: allWeights
        )

        let sortedAllWeights = allWeights.sorted { $0.date < $1.date }
        let startWeight = sortedAllWeights.first?.weightKg ?? profile?.currentWeightKg

        let transformation = JourneyStateBuilder.transformation(
            profile: profile,
            currentWeightKg: currentWeight,
            projection: goalProjection,
            weightDirection: weightSummary.direction,
            journeyStartDate: journeyStart,
            loggedDays: loggedDays
        )

        let milestones = JourneyStateBuilder.milestones(
            startWeight: startWeight,
            currentWeight: currentWeight,
            goalWeight: profile?.goalWeightKg
        )

        let weeklySnapshot = JourneyStateBuilder.weeklySnapshot(
            weekLogs: weekLogs,
            training: weeklyTraining
        )

        let coachInsights = JourneyStateBuilder.coachInsights(
            weekLogs: weekLogs,
            previousWeekLogs: previousWeekLogs,
            training: weeklyTraining,
            weightSummary: weightSummary,
            nutrition: nutritionSummary,
            water: waterSummary
        )

        let healthWorkoutDays = integrationState.isConnected
            ? JourneyTrainingSummaryBuilder.healthWorkoutDayStarts(from: allHealthWorkouts, calendar: calendar)
            : []

        let consistencyCalendar = JourneyStateBuilder.consistencyCalendar(
            logs: maturityLogs,
            healthWorkoutDayStarts: healthWorkoutDays,
            weights: allWeights
        )

        let achievements = JourneyStateBuilder.achievements(
            logs: maturityLogs,
            hasAppleHealthWorkout: integrationState.isConnected && !allHealthWorkouts.isEmpty,
            weights: allWeights,
            profile: profile
        )

        let weightChartPoints = makeWeightChartPoints(weights: weights)
        let nextCheckpoint = ProgressFormatter.nextMilestone(from: milestones)?.weightKg
        let weightLogCount = allWeights.count

        return ProgressDashboardState(
            selectedRangeDays: rangeDays,
            transformation: transformation,
            milestones: milestones,
            nextCheckpointKg: nextCheckpoint,
            sectionVisibility: JourneySectionVisibility(
                showsWeightTrendSection: weightLogCount >= 2,
                showsMilestonesSection: false
            ),
            weeklySnapshot: weeklySnapshot,
            coachInsights: coachInsights,
            consistencyCalendar: consistencyCalendar,
            achievements: achievements,
            weightTrend: JourneyWeightTrendState(
                chartPoints: weightChartPoints,
                interpretation: JourneyStateBuilder.weightTrendInterpretation(summary: weightSummary)
            ),
            analytics: ProgressAnalyticsDetail(
                nutritionSummary: nutritionSummary,
                waterSummary: waterSummary,
                workoutSummary: workoutSummary,
                weightChartPoints: weightChartPoints
            ),
            hasProfile: profile != nil
        )
    }

    // MARK: Helpers

    private func fetchHealthWorkouts(from startDate: Date, to endDate: Date) async throws -> [HealthWorkoutRecord] {
        guard trainingInsightsStore.integrationState.isConnected else {
            return []
        }
        return try await workoutReader.fetchWorkouts(from: startDate, to: endDate)
    }

    private func meaningfulLoggedDays(from logs: [DailyLog], weights: [WeightEntry]) -> Int {
        let logDays = Set(logs.filter { $0.totals.calories > 0 || $0.waterConsumedMl > 0 }.map {
            Calendar.current.startOfDay(for: $0.date)
        })
        let weightDays = Set(weights.map { Calendar.current.startOfDay(for: $0.date) })
        return logDays.union(weightDays).count
    }

    private func makeWeightChartPoints(weights: [WeightEntry]) -> [WeightChartPoint] {
        weights.sorted { $0.date < $1.date }.map {
            WeightChartPoint(date: $0.date, weightKg: $0.weightKg)
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

    private func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}
