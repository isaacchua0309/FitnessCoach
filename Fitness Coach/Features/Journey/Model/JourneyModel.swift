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
    @Published private(set) var isCrossDeviceRefreshing = false

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
    private let healthSyncPhaseProvider: () -> HealthSyncPhase?
    private let lastSuccessfulLocalSyncAtProvider: () -> Date?
    private let remoteSyncConsentDecisionProvider: () -> HealthSummarySyncConsentDecision
    private let isRemoteSyncCapabilityEnabled: () -> Bool
    private let restoreSessionState: AccountRestoreSessionState?
    private let localDataInspector: (any AccountLocalDataInspecting)?
    private let ownerUIDProvider: () -> String?
    private let accountDataRefreshEventBus: AccountDataRefreshEventBus?
    private let crossDeviceSyncCoordinator: CrossDeviceSyncCoordinating?
    private let weeklyProgressSummaryBuilder: WeeklyProgressSummaryBuilding

    private var crossDeviceRefreshCancellable: AnyCancellable?
    private var debouncedCrossDeviceReloadTask: Task<Void, Never>?
    private var activeRefreshTask: Task<Void, Never>?

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
        healthIntelligenceAnalyticsCoordinator: HealthIntelligenceAnalyticsCoordinator? = nil,
        healthSyncPhaseProvider: @escaping () -> HealthSyncPhase? = { nil },
        lastSuccessfulLocalSyncAtProvider: @escaping () -> Date? = { nil },
        remoteSyncConsentDecisionProvider: @escaping () -> HealthSummarySyncConsentDecision = { .notDetermined },
        isRemoteSyncCapabilityEnabled: @escaping () -> Bool = { false },
        restoreSessionState: AccountRestoreSessionState? = nil,
        localDataInspector: (any AccountLocalDataInspecting)? = nil,
        ownerUIDProvider: @escaping () -> String? = { nil },
        accountDataRefreshEventBus: AccountDataRefreshEventBus? = nil,
        crossDeviceSyncCoordinator: CrossDeviceSyncCoordinating? = nil,
        weeklyProgressSummaryBuilder: WeeklyProgressSummaryBuilding = WeeklyProgressSummaryBuilder()
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
        self.healthSyncPhaseProvider = healthSyncPhaseProvider
        self.lastSuccessfulLocalSyncAtProvider = lastSuccessfulLocalSyncAtProvider
        self.remoteSyncConsentDecisionProvider = remoteSyncConsentDecisionProvider
        self.isRemoteSyncCapabilityEnabled = isRemoteSyncCapabilityEnabled
        self.restoreSessionState = restoreSessionState
        self.localDataInspector = localDataInspector
        self.ownerUIDProvider = ownerUIDProvider
        self.accountDataRefreshEventBus = accountDataRefreshEventBus
        self.crossDeviceSyncCoordinator = crossDeviceSyncCoordinator
        self.weeklyProgressSummaryBuilder = weeklyProgressSummaryBuilder
        bindAccountDataRefreshEventsIfNeeded()
    }

    deinit {
        crossDeviceRefreshCancellable?.cancel()
        debouncedCrossDeviceReloadTask?.cancel()
        activeRefreshTask?.cancel()
    }

    // MARK: Cross-device refresh (Phase 5)

    func bindAccountDataRefreshEventsIfNeeded() {
        guard let accountDataRefreshEventBus else { return }
        crossDeviceRefreshCancellable?.cancel()
        crossDeviceRefreshCancellable = accountDataRefreshEventBus.events
            .compactMap { [weak self] event -> AccountDataRefreshEvent? in
                guard let self else { return nil }
                guard JourneyCrossDeviceRefreshPolicy.matchesCurrentUID(
                    event: event,
                    ownerUIDProvider: self.ownerUIDProvider
                ) else {
                    return nil
                }
                guard JourneyCrossDeviceRefreshPolicy.shouldReload(for: event) else {
                    return nil
                }
                return event
            }
            .sink { [weak self] _ in
                self?.scheduleCrossDeviceReload()
            }
    }

    func performManualCrossDeviceRefresh() async {
        guard CrossDeviceSyncLifecycle.isManualRefreshEnabled,
              let crossDeviceSyncCoordinator,
              let uid = ownerUIDProvider() else {
            return
        }

        isCrossDeviceRefreshing = true
        defer { isCrossDeviceRefreshing = false }

        _ = await crossDeviceSyncCoordinator.manualRefresh(uid: uid)
    }

    private func scheduleCrossDeviceReload() {
        debouncedCrossDeviceReloadTask?.cancel()
        debouncedCrossDeviceReloadTask = Task { @MainActor [weak self] in
            try? await Task.sleep(
                for: .milliseconds(JourneyCrossDeviceRefreshPolicy.reloadDebounceMilliseconds)
            )
            guard !Task.isCancelled, let self else { return }
            await self.refresh(forceWeeklyReviewRefresh: false)
        }
    }

    func resetForUserContextChange() {
        activeRefreshTask?.cancel()
        activeRefreshTask = nil
        debouncedCrossDeviceReloadTask?.cancel()
        debouncedCrossDeviceReloadTask = nil
        isCrossDeviceRefreshing = false
        journeyHealthIntelligenceSectionState = nil
        viewState = .loading
    }

    // MARK: Loading

    func loadProgress() async {
        viewState = .loading
        journeyHealthIntelligenceSectionState = nil
        await refresh()
    }

    func refresh(forceWeeklyReviewRefresh: Bool = false) async {
        if restoreSessionState?.isBlockingRestoreActive == true {
            if !viewState.isLoaded {
                viewState = .loading
            }
            return
        }

        let wasLoaded = viewState.isLoaded

        activeRefreshTask?.cancel()
        let task = Task { @MainActor in
            do {
                await trainingInsightsStore.refresh()
                async let dashboardTask = makeDashboardState()
                async let healthIntelligenceTask = refreshHealthIntelligenceSection(
                    forceWeeklyReviewRefresh: forceWeeklyReviewRefresh
                )
                let state = try await dashboardTask
                await healthIntelligenceTask

                guard !Task.isCancelled else { return }

                if await shouldPresentPendingRestore() {
                    viewState = .pendingAccountRestore(
                        message: restoreSessionState?.pendingRestoreMessage
                            ?? FormaProductCopy.AccountRestore.Pending.offlineBody
                    )
                    return
                }

                viewState = state.hasProfile ? .loaded(state) : .empty
            } catch is CancellationError {
                return
            } catch ServiceError.missingUserProfile {
                guard !Task.isCancelled else { return }
                journeyHealthIntelligenceSectionState = nil
                if !wasLoaded {
                    viewState = .empty
                }
            } catch {
                guard !Task.isCancelled else { return }
                journeyHealthIntelligenceSectionState = nil
                if !wasLoaded {
                    viewState = .error(FormaProductCopy.Error.loadJourney)
                }
            }
        }

        activeRefreshTask = task
        await task.value
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
                cacheStore: healthCacheStore,
                healthActivityQuery: healthActivityQuery,
                healthDataRepository: healthDataRepository,
                forceWeeklyReviewRefresh: forceWeeklyReviewRefresh
            )

            try Task.checkCancellation()

            journeyHealthIntelligenceSectionState = JourneyHealthIntelligencePresentationBuilder.buildSection(
                input: enrichedInput(from: input),
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
                uiEnabled: uiEnabled,
                errorMessage: "load_failed",
                syncPhase: healthSyncPhaseProvider()
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
        uiEnabled: Bool,
        errorMessage: String? = nil,
        syncPhase: HealthSyncPhase? = nil
    ) -> JourneyHealthIntelligenceSectionState? {
        guard uiEnabled else { return nil }

        let input = JourneyHealthIntelligenceBuildInput(
            healthConnection: isAppleHealthConnected ? .connected : .notConnected,
            errorMessage: errorMessage,
            syncPhase: syncPhase,
            lastSuccessfulLocalSyncAt: lastSuccessfulLocalSyncAtProvider(),
            isRemoteSyncCapabilityEnabled: isRemoteSyncCapabilityEnabled(),
            remoteSyncConsentDecision: remoteSyncConsentDecisionProvider()
        )

        return JourneyHealthIntelligencePresentationBuilder.buildSection(
            input: enrichedInput(from: input),
            isUIEnabled: true
        )
    }

    private func enrichedInput(
        from input: JourneyHealthIntelligenceBuildInput
    ) -> JourneyHealthIntelligenceBuildInput {
        var enriched = input
        enriched.syncPhase = input.syncPhase ?? healthSyncPhaseProvider()
        enriched.lastSuccessfulLocalSyncAt = input.lastSuccessfulLocalSyncAt ?? lastSuccessfulLocalSyncAtProvider()
        enriched.isRemoteSyncCapabilityEnabled = input.isRemoteSyncCapabilityEnabled || isRemoteSyncCapabilityEnabled()
        enriched.remoteSyncConsentDecision = input.remoteSyncConsentDecision == .notDetermined
            ? remoteSyncConsentDecisionProvider()
            : input.remoteSyncConsentDecision
        return enriched
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
            loggedDays: loggedDays,
            weeklyProgressSummaryBuilder: weeklyProgressSummaryBuilder
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

        // Deprecated fallback: remove when all JourneyModel callers inject healthActivityQuery.
        return try await workoutReader.fetchWorkouts(from: startDate, to: endDate)
    }

    private func shouldPresentPendingRestore() async -> Bool {
        await restoreSessionState?.shouldShowPendingRestoreUI(
            ownerUID: ownerUIDProvider(),
            localDataInspector: localDataInspector
        ) ?? false
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
