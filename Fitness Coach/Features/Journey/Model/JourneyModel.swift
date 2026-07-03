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
    @Published private(set) var journeyHealthIntelligenceSectionState: JourneyHealthIntelligenceSectionState?

    private let dailyLogReader: any DailyLogReading
    private let weightLogReader: any WeightLogReading
    private let userProfileReader: any UserProfileReading
    private let trainingInsightsStore: TrainingInsightsStore
    private let workoutReader: HealthKitWorkoutReading
    private let healthIntelligenceSnapshotProvider: any HealthIntelligenceSnapshotServing
    private let weeklyReviewService: any WeeklyReviewServing
    private let healthIntelligenceEngine: any HealthIntelligenceEngineing
    private let healthCacheStore: any HealthCacheStore
    private let healthActivityQuery: HealthActivityQueryService?
    private let healthDataRepository: (any HealthDataRepositorying)?
    private let healthIntelligenceLoadEnabled: () -> Bool
    private let healthIntelligenceUIEnabled: () -> Bool
    private let healthIntelligenceAnalyticsCoordinator: HealthIntelligenceAnalyticsCoordinator?

    init(
        dailyLogReader: any DailyLogReading,
        weightLogReader: any WeightLogReading,
        userProfileReader: any UserProfileReading,
        trainingInsightsStore: TrainingInsightsStore,
        workoutReader: HealthKitWorkoutReading? = nil,
        healthIntelligenceSnapshotProvider: any HealthIntelligenceSnapshotServing = NoOpHealthIntelligenceSnapshotService(),
        weeklyReviewService: any WeeklyReviewServing = NoOpWeeklyReviewService(),
        healthIntelligenceEngine: any HealthIntelligenceEngineing = NoOpHealthIntelligenceEngine(),
        healthCacheStore: any HealthCacheStore = MemoryHealthCacheStore(),
        healthActivityQuery: HealthActivityQueryService? = nil,
        healthDataRepository: (any HealthDataRepositorying)? = nil,
        healthIntelligenceLoadEnabled: @escaping () -> Bool = { HealthIntelligenceFeatureFlags.shouldJourneyModelLoadHealthIntelligence },
        healthIntelligenceUIEnabled: @escaping () -> Bool = { HealthIntelligenceFeatureFlags.isUIEnabled },
        healthIntelligenceAnalyticsCoordinator: HealthIntelligenceAnalyticsCoordinator? = nil
    ) {
        self.dailyLogReader = dailyLogReader
        self.weightLogReader = weightLogReader
        self.userProfileReader = userProfileReader
        self.trainingInsightsStore = trainingInsightsStore
        self.workoutReader = workoutReader ?? MockHealthKitWorkoutReader(workouts: [])
        self.healthIntelligenceSnapshotProvider = healthIntelligenceSnapshotProvider
        self.weeklyReviewService = weeklyReviewService
        self.healthIntelligenceEngine = healthIntelligenceEngine
        self.healthCacheStore = healthCacheStore
        self.healthActivityQuery = healthActivityQuery
        self.healthDataRepository = healthDataRepository
        self.healthIntelligenceLoadEnabled = healthIntelligenceLoadEnabled
        self.healthIntelligenceUIEnabled = healthIntelligenceUIEnabled
        self.healthIntelligenceAnalyticsCoordinator = healthIntelligenceAnalyticsCoordinator
    }

    // MARK: Loading

    func loadProgress() async {
        viewState = .loading
        journeyHealthIntelligenceSectionState = nil
        await refresh()
    }

    func refresh(forceWeeklyReviewRefresh: Bool = false) async {
        do {
            await trainingInsightsStore.refresh()
            async let dashboardTask = makeDashboardState()
            async let healthIntelligenceTask = refreshHealthIntelligenceSection(
                forceWeeklyReviewRefresh: forceWeeklyReviewRefresh
            )
            let state = try await dashboardTask
            await healthIntelligenceTask
            viewState = state.hasProfile ? .loaded(state) : .empty
        } catch ServiceError.missingUserProfile {
            journeyHealthIntelligenceSectionState = nil
            viewState = .empty
        } catch {
            journeyHealthIntelligenceSectionState = nil
            viewState = .error(FormaProductCopy.Error.loadJourney)
        }
    }

    // MARK: Health Intelligence

    private func refreshHealthIntelligenceSection(forceWeeklyReviewRefresh: Bool = false) async {
        guard healthIntelligenceLoadEnabled() else {
            journeyHealthIntelligenceSectionState = nil
            return
        }

        let uiEnabled = healthIntelligenceUIEnabled()

        guard let healthActivityQuery, let healthDataRepository else {
            journeyHealthIntelligenceSectionState = fallbackHealthIntelligenceSection(
                isAppleHealthConnected: trainingInsightsStore.integrationState.isConnected,
                uiEnabled: uiEnabled
            )
            return
        }

        do {
            try Task.checkCancellation()

            let input = await JourneyHealthIntelligenceSectionLoader.loadInput(
                referenceDate: Date(),
                isAppleHealthConnected: trainingInsightsStore.integrationState.isConnected,
                snapshotProvider: healthIntelligenceSnapshotProvider,
                weeklyReviewProvider: weeklyReviewService,
                engine: healthIntelligenceEngine,
                cacheStore: healthCacheStore,
                healthActivityQuery: healthActivityQuery,
                healthDataRepository: healthDataRepository,
                forceWeeklyReviewRefresh: forceWeeklyReviewRefresh
            )

            try Task.checkCancellation()

            journeyHealthIntelligenceSectionState = JourneyHealthIntelligencePresentationBuilder.buildSection(
                input: input,
                isUIEnabled: uiEnabled
            ) ?? fallbackHealthIntelligenceSection(
                isAppleHealthConnected: trainingInsightsStore.integrationState.isConnected,
                uiEnabled: uiEnabled
            )

            let analyticsContext = HealthIntelligencePresentationContext(
                availability: input.availability,
                snapshot: input.todaySnapshot,
                isAppleHealthConnected: input.healthConnection == .connected,
                cachedDayCount: input.cachedDayCount
            )
            healthIntelligenceAnalyticsCoordinator?.logSnapshotLoaded(
                surface: .journey,
                context: analyticsContext
            )
        } catch is CancellationError {
            return
        } catch {
            journeyHealthIntelligenceSectionState = fallbackHealthIntelligenceSection(
                isAppleHealthConnected: trainingInsightsStore.integrationState.isConnected,
                uiEnabled: uiEnabled
            )

            let analyticsContext = HealthIntelligencePresentationContext(
                explicitErrorMessage: "load_failed",
                isAppleHealthConnected: trainingInsightsStore.integrationState.isConnected
            )
            healthIntelligenceAnalyticsCoordinator?.logSnapshotFailed(
                surface: .journey,
                context: analyticsContext,
                error: error
            )
        }
    }

    private func fallbackHealthIntelligenceSection(
        isAppleHealthConnected: Bool,
        uiEnabled: Bool
    ) -> JourneyHealthIntelligenceSectionState? {
        guard uiEnabled else { return nil }

        return JourneyHealthIntelligencePresentationBuilder.buildSection(
            input: JourneyHealthIntelligenceBuildInput(
                healthConnection: isAppleHealthConnected ? .connected : .notConnected
            ),
            isUIEnabled: true
        )
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

        if let healthActivityQuery {
            return await healthActivityQuery.workouts(from: startDate, to: endDate)
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

    func applyPreviewHealthIntelligenceState(_ state: JourneyHealthIntelligenceSectionState?) {
        journeyHealthIntelligenceSectionState = state
    }

    static func preview(
        scenario: JourneyPreviewData.Scenario = .strongMomentum
    ) -> JourneyModel {
        let container = try! AppContainer(inMemory: true)
        let model = container.makeJourneyModel()
        model.applyPreviewState(JourneyPreviewData.dashboard(scenario))
        model.applyPreviewHealthIntelligenceState(JourneyHealthIntelligencePreviewData.strongWeek)
        return model
    }
#endif
}
