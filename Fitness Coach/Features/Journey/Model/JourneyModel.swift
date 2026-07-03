//
//  JourneyModel.swift
//  Fitness Coach
//
//  FitPilot AI — Read-only Journey transformation state.
//

import Combine
import Foundation

@MainActor
final class JourneyModel: ObservableObject {

    @Published private(set) var viewState: JourneyViewState = .loading

    private let dailyLogReader: any DailyLogReading
    private let weightLogReader: any WeightLogReading
    private let userProfileReader: any UserProfileReading
    private let trainingInsightsStore: TrainingInsightsStore
    private let workoutReader: HealthKitWorkoutReading

    init(
        dailyLogReader: any DailyLogReading,
        weightLogReader: any WeightLogReading,
        userProfileReader: any UserProfileReading,
        trainingInsightsStore: TrainingInsightsStore,
        workoutReader: HealthKitWorkoutReading? = nil
    ) {
        self.dailyLogReader = dailyLogReader
        self.weightLogReader = weightLogReader
        self.userProfileReader = userProfileReader
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
            let state = try await makeDashboardState()
            viewState = state.hasProfile ? .loaded(state) : .empty
        } catch ServiceError.missingUserProfile {
            viewState = .empty
        } catch {
            viewState = .error(FormaProductCopy.Error.loadJourney)
        }
    }

    // MARK: State Building

    private func makeDashboardState() async throws -> JourneyDashboardState {
        let calendar = Calendar.current
        let endDate = Date()
        let weekStart = calendar.date(byAdding: .day, value: -6, to: endDate) ?? endDate
        let prevWeekStart = calendar.date(byAdding: .day, value: -13, to: endDate) ?? endDate
        let prevWeekEnd = calendar.date(byAdding: .day, value: -7, to: endDate) ?? endDate
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: endDate)) ?? endDate
        let allTimeStart = calendar.date(byAdding: .day, value: -365, to: endDate) ?? endDate

        let weekLogs = try dailyLogReader.getLogs(from: weekStart, to: endDate)
        let previousWeekLogs = try dailyLogReader.getLogs(from: prevWeekStart, to: prevWeekEnd)
        let monthLogs = try dailyLogReader.getLogs(from: monthStart, to: endDate)
        let maturityLogs = try dailyLogReader.getLogs(from: allTimeStart, to: endDate)

        let allWeights = try weightLogReader.getWeightEntries(from: allTimeStart, to: endDate)
        let weekWeights = try weightLogReader.getWeightEntries(from: weekStart, to: endDate)
        let previousWeekWeights = try weightLogReader.getWeightEntries(from: prevWeekStart, to: prevWeekEnd)

        let integrationState = trainingInsightsStore.integrationState
        let dataSource = trainingInsightsStore.dataSource

        let weekHealthWorkouts = try await fetchHealthWorkouts(from: weekStart, to: endDate)
        let previousWeekHealthWorkouts = try await fetchHealthWorkouts(from: prevWeekStart, to: prevWeekEnd)
        let monthHealthWorkouts = try await fetchHealthWorkouts(from: monthStart, to: endDate)
        let allHealthWorkouts = try await fetchHealthWorkouts(from: allTimeStart, to: endDate)

        let weeklyTraining = JourneyTrainingSummaryBuilder.weeklyTrainingStatus(
            integrationState: integrationState,
            dataSource: dataSource,
            weekWorkouts: weekHealthWorkouts,
            asOf: endDate,
            calendar: calendar
        )
        let previousWeekTrainingDays = integrationState.isConnected
            ? JourneyTrainingSummaryBuilder.healthWorkoutDayStarts(
                from: previousWeekHealthWorkouts,
                calendar: calendar
            ).count
            : 0

        let profile = try userProfileReader.getCurrentProfile()

        let weightTrend = WeightTrendCalculator.trend(from: allWeights, endingOn: endDate)
        let weightSummary = ProgressWeightSummary(
            latestWeightKg: weightTrend.latestWeightKg,
            changeKg: weightTrend.changeKg ?? WeightTrendCalculator.weightChange(from: allWeights),
            direction: weightTrend.direction,
            hasSuddenSpike: weightTrend.hasSuddenSpike
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
            asOf: endDate,
            calendar: calendar
        )

        let journeyStreaks = JourneyStreakBuilder.build(
            JourneyStreakBuilder.Input(
                streakSummary: streakSummary,
                maturityLogs: maturityLogs,
                workoutDates: healthWorkoutDays,
                isAppleHealthConnected: integrationState.isConnected,
                asOf: endDate,
                calendar: calendar
            )
        )

        let loggedDays = meaningfulLoggedDays(from: maturityLogs, weights: allWeights)

        let builderContext = JourneyDashboardBuilder.Context(
            profile: profile,
            baseline: baseline,
            maturityLogs: maturityLogs,
            monthLogs: monthLogs,
            weekLogs: weekLogs,
            previousWeekLogs: previousWeekLogs,
            previousWeekWeights: previousWeekWeights,
            previousWeekTrainingDays: previousWeekTrainingDays,
            allWeights: allWeights,
            weekWeights: weekWeights,
            journeyStreaks: journeyStreaks,
            weeklyTraining: weeklyTraining,
            weightSummary: weightSummary,
            goalProjection: goalProjection,
            healthWorkoutDayStarts: healthWorkoutDays,
            monthHealthWorkoutCount: monthHealthWorkouts.count,
            asOf: endDate,
            calendar: calendar
        )

        return JourneyPresentationBuilder.buildDashboard(
            hasProfile: profile != nil,
            context: builderContext,
            loggedDays: loggedDays
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

#if DEBUG
    /// Applies a static dashboard for SwiftUI previews without loading services.
    func applyPreviewState(_ state: JourneyDashboardState) {
        viewState = .loaded(state)
    }

    static func preview(
        scenario: JourneyPreviewData.Scenario = .strongMomentum
    ) -> JourneyModel {
        let container = try! AppContainer(inMemory: true)
        let model = container.makeJourneyModel()
        model.applyPreviewState(JourneyPreviewData.dashboard(scenario))
        return model
    }
#endif
}
