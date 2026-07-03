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
    private let healthIntelligenceLoadEnabled: () -> Bool
    private let healthIntelligenceUIEnabled: () -> Bool
    private let healthIntelligenceAnalyticsCoordinator: HealthIntelligenceAnalyticsCoordinator?
    private let healthSyncPhaseProvider: () -> HealthSyncPhase?
    private let lastSuccessfulLocalSyncAtProvider: () -> Date?
    private let remoteSyncConsentDecisionProvider: () -> HealthSummarySyncConsentDecision
    private let isRemoteSyncCapabilityEnabled: () -> Bool

    private var activityContext: TodayActivityContext = .default
    private var boundHydrationContext: TodayHydrationContext?
    private var activeLoadTask: Task<Void, Never>?

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
        healthIntelligenceLoadEnabled: @escaping () -> Bool = { HealthIntelligenceFeatureFlags.shouldTodayModelLoadHealthIntelligence },
        healthIntelligenceUIEnabled: @escaping () -> Bool = { HealthIntelligenceFeatureFlags.isUIEnabled },
        healthIntelligenceAnalyticsCoordinator: HealthIntelligenceAnalyticsCoordinator? = nil,
        healthSyncPhaseProvider: @escaping () -> HealthSyncPhase? = { nil },
        lastSuccessfulLocalSyncAtProvider: @escaping () -> Date? = { nil },
        remoteSyncConsentDecisionProvider: @escaping () -> HealthSummarySyncConsentDecision = { .notDetermined },
        isRemoteSyncCapabilityEnabled: @escaping () -> Bool = { HealthIntelligenceFeatureFlags.healthSummaryRemoteSyncEnabled }
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
        self.healthIntelligenceLoadEnabled = healthIntelligenceLoadEnabled
        self.healthIntelligenceUIEnabled = healthIntelligenceUIEnabled
        self.healthIntelligenceAnalyticsCoordinator = healthIntelligenceAnalyticsCoordinator
        self.healthSyncPhaseProvider = healthSyncPhaseProvider
        self.lastSuccessfulLocalSyncAtProvider = lastSuccessfulLocalSyncAtProvider
        self.remoteSyncConsentDecisionProvider = remoteSyncConsentDecisionProvider
        self.isRemoteSyncCapabilityEnabled = isRemoteSyncCapabilityEnabled
    }

    // MARK: Session lifecycle

    func resetForUserContextChange() {
        activeLoadTask?.cancel()
        activeLoadTask = nil
        boundHydrationContext = nil
        healthIntelligenceSectionState = nil
        viewState = .loading
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
        case .error: return "error"
        }
    }

    private func loadDashboard() async throws {
        let dailyLog = try dailyLogReader.getTodayLog()
        let foodEntries = try foodLogReader.getFoodEntries(for: dailyLog.date)
        let latestWeight = dailyLog.weightKg == nil ? try weightLogReader.getLatestWeight() : nil
        let dailyReview = try dailyReviewReader.getDailyReview(for: dailyLog.date)
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

        viewState = .loaded(
            try await makeDashboardState(
                dailyLog: dailyLog,
                foodEntries: foodEntries,
                training: training,
                latestWeight: latestWeight,
                dailyReview: dailyReview
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
        dailyReview: DailyReview?
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
                dailyReview: dailyReview,
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
}
