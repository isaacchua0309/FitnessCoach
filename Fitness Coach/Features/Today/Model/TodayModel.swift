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
    @Published private(set) var healthIntelligenceSectionState: TodayHealthIntelligenceSectionState?
    @Published private(set) var isCrossDeviceRefreshing = false

    private let dailyLogReader: any DailyLogReading
    private let foodLogReader: any FoodLogReading
    private let weightLogReader: any WeightLogReading
    private let dailyReviewReader: any DailyReviewReading
    private let userProfileReader: any UserProfileReading
    private let healthActivityQuery: HealthActivityQueryService
    private let healthIntelligenceSnapshotProvider: any HealthIntelligenceSnapshotServing
    private let healthDataRepository: (any HealthDataRepositorying)?
    private let hydrationContextProvider: () -> TodayHydrationContext?
    private let authStateProvider: () -> AuthState
    private let restoreSessionState: AccountRestoreSessionState?
    private let localDataInspector: (any AccountLocalDataInspecting)?
    private let ownerUIDProvider: () -> String?
    private let healthIntelligenceLoadEnabled: () -> Bool
    private let healthIntelligenceUIEnabled: () -> Bool
    private let healthIntelligenceAnalyticsCoordinator: HealthIntelligenceAnalyticsCoordinator?
    private let healthSyncPhaseProvider: () -> HealthSyncPhase?
    private let lastSuccessfulLocalSyncAtProvider: () -> Date?
    private let remoteSyncConsentDecisionProvider: () -> HealthSummarySyncConsentDecision
    private let isRemoteSyncCapabilityEnabled: () -> Bool
    private let accountDataRefreshEventBus: AccountDataRefreshEventBus?
    private let crossDeviceSyncCoordinator: CrossDeviceSyncCoordinating?

    private var activityContext: TodayActivityContext = .default
    private var boundHydrationContext: TodayHydrationContext?
    private var activeLoadTask: Task<Void, Never>?
    private var crossDeviceRefreshCancellable: AnyCancellable?
    private var debouncedCrossDeviceReloadTask: Task<Void, Never>?

    init(
        dailyLogReader: any DailyLogReading,
        foodLogReader: any FoodLogReading,
        weightLogReader: any WeightLogReading,
        dailyReviewReader: any DailyReviewReading,
        userProfileReader: any UserProfileReading,
        healthActivityQuery: HealthActivityQueryService,
        healthIntelligenceSnapshotProvider: any HealthIntelligenceSnapshotServing = NoOpHealthIntelligenceSnapshotService(),
        healthDataRepository: (any HealthDataRepositorying)? = nil,
        hydrationContextProvider: @escaping () -> TodayHydrationContext? = { nil },
        authStateProvider: @escaping () -> AuthState = { .unknown },
        restoreSessionState: AccountRestoreSessionState? = nil,
        localDataInspector: (any AccountLocalDataInspecting)? = nil,
        ownerUIDProvider: @escaping () -> String? = { nil },
        healthIntelligenceLoadEnabled: @escaping () -> Bool = { HealthIntelligenceFeatureFlags.shouldTodayModelLoadHealthIntelligence },
        healthIntelligenceUIEnabled: @escaping () -> Bool = { HealthIntelligenceFeatureFlags.isUIEnabled },
        healthIntelligenceAnalyticsCoordinator: HealthIntelligenceAnalyticsCoordinator? = nil,
        healthSyncPhaseProvider: @escaping () -> HealthSyncPhase? = { nil },
        lastSuccessfulLocalSyncAtProvider: @escaping () -> Date? = { nil },
        remoteSyncConsentDecisionProvider: @escaping () -> HealthSummarySyncConsentDecision = { .notDetermined },
        isRemoteSyncCapabilityEnabled: @escaping () -> Bool = { HealthIntelligenceFeatureFlags.healthSummaryRemoteSyncEnabled },
        accountDataRefreshEventBus: AccountDataRefreshEventBus? = nil,
        crossDeviceSyncCoordinator: CrossDeviceSyncCoordinating? = nil
    ) {
        self.dailyLogReader = dailyLogReader
        self.foodLogReader = foodLogReader
        self.weightLogReader = weightLogReader
        self.dailyReviewReader = dailyReviewReader
        self.userProfileReader = userProfileReader
        self.healthActivityQuery = healthActivityQuery
        self.healthIntelligenceSnapshotProvider = healthIntelligenceSnapshotProvider
        self.healthDataRepository = healthDataRepository
        self.hydrationContextProvider = hydrationContextProvider
        self.authStateProvider = authStateProvider
        self.restoreSessionState = restoreSessionState
        self.localDataInspector = localDataInspector
        self.ownerUIDProvider = ownerUIDProvider
        self.healthIntelligenceLoadEnabled = healthIntelligenceLoadEnabled
        self.healthIntelligenceUIEnabled = healthIntelligenceUIEnabled
        self.healthIntelligenceAnalyticsCoordinator = healthIntelligenceAnalyticsCoordinator
        self.healthSyncPhaseProvider = healthSyncPhaseProvider
        self.lastSuccessfulLocalSyncAtProvider = lastSuccessfulLocalSyncAtProvider
        self.remoteSyncConsentDecisionProvider = remoteSyncConsentDecisionProvider
        self.isRemoteSyncCapabilityEnabled = isRemoteSyncCapabilityEnabled
        self.accountDataRefreshEventBus = accountDataRefreshEventBus
        self.crossDeviceSyncCoordinator = crossDeviceSyncCoordinator
        bindAccountDataRefreshEventsIfNeeded()
    }

    deinit {
        crossDeviceRefreshCancellable?.cancel()
        debouncedCrossDeviceReloadTask?.cancel()
    }

    // MARK: Session lifecycle

    func resetForUserContextChange() {
        activeLoadTask?.cancel()
        activeLoadTask = nil
        debouncedCrossDeviceReloadTask?.cancel()
        debouncedCrossDeviceReloadTask = nil
        isCrossDeviceRefreshing = false
        boundHydrationContext = nil
        healthIntelligenceSectionState = nil
        viewState = .loading
    }

    // MARK: Cross-device refresh (Phase 5)

    func bindAccountDataRefreshEventsIfNeeded() {
        guard let accountDataRefreshEventBus else { return }
        crossDeviceRefreshCancellable?.cancel()
        crossDeviceRefreshCancellable = accountDataRefreshEventBus.events
            .compactMap { [weak self] event -> AccountDataRefreshEvent? in
                guard let self else { return nil }
                guard TodayCrossDeviceRefreshPolicy.matchesCurrentUID(
                    event: event,
                    ownerUIDProvider: self.ownerUIDProvider
                ) else {
                    return nil
                }
                guard TodayCrossDeviceRefreshPolicy.shouldReload(for: event) else {
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
                for: .milliseconds(TodayCrossDeviceRefreshPolicy.reloadDebounceMilliseconds)
            )
            guard !Task.isCancelled, let self else { return }
            await self.refresh(activityContext: self.activityContext)
        }
    }

    // MARK: Loading

    func loadToday(activityContext: TodayActivityContext = .default) async {
        self.activityContext = activityContext
        await performLoad(isRefresh: false)
    }

    func refresh(activityContext: TodayActivityContext? = nil) async {
        if let activityContext {
            self.activityContext = activityContext
        }

        guard hydrationContextProvider() != nil else {
            if boundHydrationContext != nil {
                resetForUserContextChange()
            } else if !viewState.isLoaded {
                viewState = .loading
            }
            return
        }

        guard viewState.isLoaded else {
            await loadToday(activityContext: self.activityContext)
            return
        }

        await performLoad(isRefresh: true)
    }

    // MARK: State Building

    private func performLoad(isRefresh: Bool) async {
        if restoreSessionState?.isBlockingRestoreActive == true {
            viewState = .loading
            return
        }

        guard let context = hydrationContextProvider() else {
            let profileOwnerUID = try? userProfileReader.getCurrentProfile()?.ownerUID
            TodayHydrationDebugLogger.deferred(
                authState: authStateProvider(),
                profileOwnerUID: profileOwnerUID,
                reason: "signed_in_profile_context_unresolved"
            )
            if boundHydrationContext != nil {
                resetForUserContextChange()
            } else if !viewState.isLoaded {
                viewState = .loading
            }
            return
        }

        if boundHydrationContext?.sessionUID != context.sessionUID {
            if let previousUID = boundHydrationContext?.sessionUID {
                TodayHydrationDebugLogger.sessionRebound(from: previousUID, to: context.sessionUID)
            }
            resetForUserContextChange()
            boundHydrationContext = context
        } else {
            boundHydrationContext = context
        }

        activeLoadTask?.cancel()

        let task = Task { @MainActor in
            TodayHydrationDebugLogger.loadStarted(
                context: context,
                isRefresh: isRefresh,
                viewState: viewStateLabel
            )

            if !isRefresh, !viewState.isLoaded {
                viewState = .loading
            }

            do {
                try Task.checkCancellation()
                try await loadDashboard()
                guard !Task.isCancelled else { return }
                TodayHydrationDebugLogger.loadSucceeded(context: context, isRefresh: isRefresh)
            } catch is CancellationError {
                return
            } catch ServiceError.missingUserProfile {
                guard !Task.isCancelled else { return }
                viewState = .empty
            } catch {
                guard !Task.isCancelled else { return }
                if isRefresh, viewState.isLoaded {
                    TodayHydrationDebugLogger.loadFailed(
                        context: context,
                        isRefresh: true,
                        keptStaleLoadedState: true,
                        error: error
                    )
                    return
                }
                viewState = .error(
                    TodayLoadErrorFormatting.message(for: error, isRefresh: isRefresh)
                )
                TodayHydrationDebugLogger.loadFailed(
                    context: context,
                    isRefresh: isRefresh,
                    keptStaleLoadedState: false,
                    error: error
                )
            }
        }

        activeLoadTask = task
        await task.value
    }

    private var viewStateLabel: String {
        switch viewState {
        case .loading: return "loading"
        case .loaded: return "loaded"
        case .empty: return "empty"
        case .pendingAccountRestore: return "pendingAccountRestore"
        case .error: return "error"
        }
    }

    private func loadDashboard() async throws {
        let dailyLog = try dailyLogReader.getTodayLog()
        let foodEntries = try foodLogReader.getFoodEntries(for: dailyLog.date)
        let latestWeight = dailyLog.weightKg == nil ? try weightLogReader.getLatestWeight() : nil
        let yesterdayReviewInput = try makeYesterdayReviewInput(relativeTo: dailyLog.date)
        let nutrition = DailyNutritionSummaryBuilder.build(from: dailyLog)
        let (calorieSummary, macroSummary, waterSummary) = TodayDashboardNutritionMapper.maps(from: nutrition)

        async let trainingTask = optionalDailyTrainingActivity(on: dailyLog.date)
        async let healthIntelligenceTask = refreshHealthIntelligenceSection(
            for: dailyLog.date,
            calorieSummary: calorieSummary,
            macroSummary: macroSummary,
            waterSummary: waterSummary
        )

        let training = await trainingTask
        await healthIntelligenceTask

        if await shouldPresentPendingRestore() {
            viewState = .pendingAccountRestore(
                message: restoreSessionState?.pendingRestoreMessage
                    ?? FormaProductCopy.AccountRestore.Pending.todayBody
            )
            return
        }

        viewState = .loaded(
            try await makeDashboardState(
                dailyLog: dailyLog,
                foodEntries: foodEntries,
                training: training,
                latestWeight: latestWeight,
                yesterdayReviewInput: yesterdayReviewInput
            )
        )
    }

    private func refreshHealthIntelligenceSection(
        for date: Date,
        calorieSummary: CalorieSummary,
        macroSummary: MacroSummary,
        waterSummary: WaterSummary
    ) async {
        guard healthIntelligenceLoadEnabled() else {
            healthIntelligenceSectionState = nil
            return
        }

        let nutritionProgress = TodayHealthIntelligenceNutritionProgress.from(
            calorieSummary: calorieSummary,
            macroSummary: macroSummary,
            waterSummary: waterSummary
        )
        let uiEnabled = healthIntelligenceUIEnabled()
        let isAppleHealthConnected = activityContext.trainingIntegration.isConnected

        do {
            try Task.checkCancellation()
            async let snapshotTask = healthIntelligenceSnapshotProvider.loadTodaySnapshot(
                for: date,
                calendar: .current
            )
            async let availabilityTask: HealthDataAvailability? = {
                guard let healthDataRepository else { return nil }
                return await healthDataRepository.getHealthDataAvailability()
            }()

            let snapshot = await snapshotTask
            let availability = await availabilityTask
            try Task.checkCancellation()

            healthIntelligenceSectionState = buildHealthIntelligenceSection(
                snapshot: snapshot,
                nutritionProgress: nutritionProgress,
                uiEnabled: uiEnabled,
                availability: availability,
                isAppleHealthConnected: isAppleHealthConnected
            ) ?? fallbackHealthIntelligenceSection(
                nutritionProgress: nutritionProgress,
                uiEnabled: uiEnabled,
                availability: availability,
                isAppleHealthConnected: isAppleHealthConnected
            )

            let analyticsContext = HealthIntelligencePresentationContext(
                availability: availability,
                snapshot: snapshot,
                isAppleHealthConnected: isAppleHealthConnected,
                cachedDayCount: availability?.cachedDayCount ?? 0
            )
            healthIntelligenceAnalyticsCoordinator?.logSnapshotLoaded(
                surface: .today,
                context: analyticsContext
            )
        } catch is CancellationError {
            return
        } catch {
            healthIntelligenceSectionState = fallbackHealthIntelligenceSection(
                nutritionProgress: nutritionProgress,
                uiEnabled: uiEnabled,
                availability: nil,
                isAppleHealthConnected: isAppleHealthConnected,
                errorMessage: "load_failed"
            )

            let analyticsContext = HealthIntelligencePresentationContext(
                explicitErrorMessage: "load_failed",
                snapshot: nil,
                isAppleHealthConnected: isAppleHealthConnected
            )
            healthIntelligenceAnalyticsCoordinator?.logSnapshotFailed(
                surface: .today,
                context: analyticsContext,
                error: error
            )
        }
    }

    private func buildHealthIntelligenceSection(
        snapshot: HealthIntelligenceSnapshot?,
        nutritionProgress: TodayHealthIntelligenceNutritionProgress,
        uiEnabled: Bool,
        availability: HealthDataAvailability?,
        isAppleHealthConnected: Bool,
        errorMessage: String? = nil
    ) -> TodayHealthIntelligenceSectionState? {
        guard uiEnabled else { return nil }

        return TodayHealthIntelligencePresentationBuilder.buildSection(
            snapshot: snapshot,
            nutritionProgress: nutritionProgress,
            isUIEnabled: true,
            availability: availability,
            isAppleHealthConnected: isAppleHealthConnected,
            cachedDayCount: availability?.cachedDayCount ?? 0,
            errorMessage: errorMessage,
            syncPhase: healthSyncPhaseProvider(),
            lastSuccessfulLocalSyncAt: lastSuccessfulLocalSyncAtProvider(),
            isRemoteSyncCapabilityEnabled: isRemoteSyncCapabilityEnabled(),
            remoteSyncConsentDecision: remoteSyncConsentDecisionProvider()
        )
    }

    private func fallbackHealthIntelligenceSection(
        nutritionProgress: TodayHealthIntelligenceNutritionProgress,
        uiEnabled: Bool,
        availability: HealthDataAvailability?,
        isAppleHealthConnected: Bool,
        errorMessage: String? = nil
    ) -> TodayHealthIntelligenceSectionState? {
        buildHealthIntelligenceSection(
            snapshot: nil,
            nutritionProgress: nutritionProgress,
            uiEnabled: uiEnabled,
            availability: availability,
            isAppleHealthConnected: isAppleHealthConnected,
            errorMessage: errorMessage
        )
    }

    private func makeDashboardState(
        dailyLog: DailyLog,
        foodEntries: [FoodEntry],
        training: DailyTrainingActivity,
        latestWeight: WeightEntry?,
        yesterdayReviewInput: TodayYesterdayReviewInput?
    ) async throws -> TodayDashboardState {
        let nutrition = DailyNutritionSummaryBuilder.build(from: dailyLog)
        let (calorieSummary, macroSummary, waterSummary) = TodayDashboardNutritionMapper.maps(from: nutrition)

        let profile = try? userProfileReader.getCurrentProfile()

        let displayWeight = dailyLog.weightKg ?? latestWeight?.weightKg
        let weightSummary = TodayWeightSummary(
            weightKg: displayWeight,
            displayText: displayWeight.map { String(format: "%.2f kg", $0) }
                ?? "Not logged today"
        )
        let weightLoggedToday = dailyLog.weightKg != nil
        let hasRecentWeight = latestWeight != nil || profile?.currentWeightKg != nil

        let workoutSummary = TodayWorkoutSummary(
            // Legacy merge: prefers the higher of manual log vs HealthKit aggregate.
            // Remove after HI workout display fully owns Today activity calories.
            workoutCaloriesBurned: max(dailyLog.workoutCaloriesBurned, training.workoutCaloriesBurned),
            workoutCount: training.workoutCount,
            hasWorkout: training.hasWorkout
        )

        let hasPriorFoodLogs = try hasPriorFoodLogs(before: dailyLog.date)

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
                yesterdayReviewInput: yesterdayReviewInput,
                goalWeightKg: profile?.goalWeightKg,
                profileWeightKg: profile?.currentWeightKg,
                latestWeightKg: displayWeight,
                activityContext: activityContext,
                stepGoalAssumption: profile.flatMap { $0.averageSteps > 0 ? $0.averageSteps : nil },
                trainingFrequencyPerWeek: profile?.trainingFrequencyPerWeek ?? 0
            )
        )
    }

    private func optionalDailyTrainingActivity(on date: Date) async -> DailyTrainingActivity {
        guard activityContext.trainingIntegration.isConnected else {
            return .empty
        }
        return await healthActivityQuery.dailyTrainingActivity(on: date)
    }

    private func shouldPresentPendingRestore() async -> Bool {
        await restoreSessionState?.shouldShowPendingRestoreUI(
            ownerUID: ownerUIDProvider(),
            localDataInspector: localDataInspector
        ) ?? false
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

        let logs = try dailyLogReader.getLogs(from: lookbackStart, to: yesterday)
        return logs.contains { log in
            calendar.startOfDay(for: log.date) < todayStart && log.totals.calories > 0
        }
    }

    private func makeYesterdayReviewInput(relativeTo date: Date) throws -> TodayYesterdayReviewInput? {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: date)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: todayStart) else {
            return nil
        }

        let yesterdayLog = try dailyLogReader.getLog(for: yesterday)
        let foodEntries = try foodLogReader.getFoodEntries(for: yesterday)
        let review = try dailyReviewReader.getDailyReview(for: yesterday)

        let waterConsumedMl = yesterdayLog?.waterConsumedMl ?? 0
        let workoutCaloriesBurned = yesterdayLog?.workoutCaloriesBurned ?? 0
        let weightLogged = yesterdayLog?.weightKg != nil

        return TodayYesterdayReviewInput(
            date: yesterday,
            review: review,
            foodEntryCount: foodEntries.count,
            waterConsumedMl: waterConsumedMl,
            workoutCaloriesBurned: workoutCaloriesBurned,
            weightLogged: weightLogged
        )
    }
}
