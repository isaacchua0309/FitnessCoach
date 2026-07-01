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

    private let dailyLogReader: any DailyLogReading
    private let foodLogReader: any FoodLogReading
    private let weightLogReader: any WeightLogReading
    private let dailyReviewReader: any DailyReviewReading
    private let userProfileReader: any UserProfileReading
    private let healthActivityQuery: HealthActivityQueryService
    private let hydrationContextProvider: () -> TodayHydrationContext?
    private let authStateProvider: () -> AuthState

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
        hydrationContextProvider: @escaping () -> TodayHydrationContext? = { nil },
        authStateProvider: @escaping () -> AuthState = { .unknown }
    ) {
        self.dailyLogReader = dailyLogReader
        self.foodLogReader = foodLogReader
        self.weightLogReader = weightLogReader
        self.dailyReviewReader = dailyReviewReader
        self.userProfileReader = userProfileReader
        self.healthActivityQuery = healthActivityQuery
        self.hydrationContextProvider = hydrationContextProvider
        self.authStateProvider = authStateProvider
    }

    // MARK: Session lifecycle

    func resetForUserContextChange() {
        activeLoadTask?.cancel()
        activeLoadTask = nil
        boundHydrationContext = nil
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
        let training = try await healthActivityQuery.dailyTrainingActivity(on: dailyLog.date)
        let latestWeight = dailyLog.weightKg == nil ? try weightLogReader.getLatestWeight() : nil
        let dailyReview = try dailyReviewReader.getDailyReview(for: dailyLog.date)

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
            workoutCaloriesBurned: max(dailyLog.workoutCaloriesBurned, training.workoutCaloriesBurned),
            workoutCount: training.workoutCount,
            hasWorkout: training.hasWorkout
        )

        let trainingFrequency = profile?.trainingFrequencyPerWeek ?? 0
        let (streaks, weekLoggedDays) = try await buildMomentumMetrics(asOf: dailyLog.date)
        let hasPriorFoodLogs = try hasPriorFoodLogs(before: dailyLog.date)
        let dailyBrief = DailyBriefBuilder.todayBrief(
            nutrition: nutrition,
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

    private func buildMomentumMetrics(asOf date: Date) async throws -> (StreakSummary, Int) {
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -90, to: date) ?? date
        let logs = try dailyLogReader.getLogs(from: startDate, to: date)
        let workoutDates = try await healthActivityQuery.workoutDayStarts(
            from: startDate,
            to: date,
            calendar: calendar
        )
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

        let logs = try dailyLogReader.getLogs(from: lookbackStart, to: yesterday)
        return logs.contains { log in
            calendar.startOfDay(for: log.date) < todayStart && log.totals.calories > 0
        }
    }
}
