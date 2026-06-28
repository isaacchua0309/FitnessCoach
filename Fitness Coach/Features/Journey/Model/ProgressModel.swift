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
        userProfileService: UserProfileService,
        trainingInsightsStore: TrainingInsightsStore,
        workoutReader: HealthKitWorkoutReading? = nil
    ) {
        self.dailyLogService = dailyLogService
        self.weightLogService = weightLogService
        self.userProfileService = userProfileService
        self.trainingInsightsStore = trainingInsightsStore
        self.workoutReader = workoutReader ?? MockHealthKitWorkoutReader(workouts: [])
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
        let monthStart = calendar.dateInterval(of: .month, for: endDate)?.start ?? endDate

        let logs = try dailyLogService.getLogs(from: startDate, to: endDate)
        let weekLogs = try dailyLogService.getLogs(from: weekStart, to: endDate)
        let previousWeekLogs = try dailyLogService.getLogs(from: prevWeekStart, to: prevWeekEnd)
        let maturityLogs = try dailyLogService.getLogs(from: allTimeStart, to: endDate)
        let monthLogs = try dailyLogService.getLogs(from: monthStart, to: endDate)

        let weights = try weightLogService.getWeightEntries(from: startDate, to: endDate)
        let allWeights = try weightLogService.getWeightEntries(from: allTimeStart, to: endDate)
        let weekWeights = try weightLogService.getWeightEntries(from: weekStart, to: endDate)

        let integrationState = trainingInsightsStore.integrationState
        let dataSource = trainingInsightsStore.dataSource

        let rangeHealthWorkouts = try await fetchHealthWorkouts(from: startDate, to: endDate)
        let weekHealthWorkouts = try await fetchHealthWorkouts(from: weekStart, to: endDate)
        let allHealthWorkouts = try await fetchHealthWorkouts(from: allTimeStart, to: endDate)
        let monthHealthWorkouts = try await fetchHealthWorkouts(from: monthStart, to: endDate)

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

        let nutritionSummary = ProgressLogSummaryBuilder.nutritionSummary(from: logs)
        let waterSummary = ProgressLogSummaryBuilder.waterSummary(from: logs)
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

        let baseline = JourneyBaselineResolver.resolve(
            JourneyBaselineResolver.Input(
                profile: profile,
                allWeights: allWeights,
                maturityLogs: maturityLogs,
                goalProjection: goalProjection,
                asOf: endDate,
                calendar: calendar
            )
        )

        let healthWorkoutDays = integrationState.isConnected
            ? JourneyTrainingSummaryBuilder.healthWorkoutDayStarts(from: allHealthWorkouts, calendar: calendar)
            : []

        let streakSummary = StreakCalculator.calculate(
            logs: maturityLogs,
            workoutDates: healthWorkoutDays,
            asOf: endDate
        )

        let loggedDays = meaningfulLoggedDays(from: maturityLogs, weights: allWeights)
        let weightInterpretation = JourneyDashboardBuilder.weightTrendInterpretation(summary: weightSummary)

        let builderContext = JourneyDashboardBuilder.Context(
            profile: profile,
            baseline: baseline,
            maturityLogs: maturityLogs,
            weekLogs: weekLogs,
            previousWeekLogs: previousWeekLogs,
            monthLogs: monthLogs,
            rangeLogs: logs,
            allWeights: allWeights,
            weekWeights: weekWeights,
            rangeWeights: weights,
            streakSummary: streakSummary,
            weeklyTraining: weeklyTraining,
            weightSummary: weightSummary,
            goalProjection: goalProjection,
            healthWorkoutDayStarts: healthWorkoutDays,
            monthHealthWorkoutCount: monthHealthWorkouts.count,
            weekHealthWorkoutCount: weekHealthWorkouts.count,
            loggedDays: loggedDays,
            nutritionSummary: nutritionSummary,
            waterSummary: waterSummary,
            workoutSummary: workoutSummary,
            selectedRangeDays: rangeDays,
            asOf: endDate,
            calendar: calendar
        )

        return ProgressDashboardState(
            selectedRangeDays: rangeDays,
            hasProfile: profile != nil,
            baseline: baseline,
            transformation: JourneyDashboardBuilder.transformation(
                context: builderContext,
                loggedDays: loggedDays
            ),
            weeklyReview: JourneyDashboardBuilder.weeklyReview(context: builderContext),
            milestones: JourneyDashboardBuilder.milestones(context: builderContext),
            storyTimeline: JourneyDashboardBuilder.storyTimeline(context: builderContext),
            habitInsights: JourneyDashboardBuilder.habitInsights(context: builderContext),
            progressAttribution: JourneyDashboardBuilder.progressAttribution(context: builderContext),
            beforeToday: JourneyDashboardBuilder.beforeToday(context: builderContext),
            personalRecords: JourneyDashboardBuilder.personalRecords(context: builderContext),
            monthlyRecap: JourneyDashboardBuilder.monthlyRecap(context: builderContext),
            journeyLevel: JourneyDashboardBuilder.journeyLevel(context: builderContext),
            detailedAnalytics: JourneyDashboardBuilder.detailedAnalytics(
                context: builderContext,
                weightInterpretation: weightInterpretation
            )
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
}
