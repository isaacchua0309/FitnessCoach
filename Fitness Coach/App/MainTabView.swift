//
//  MainTabView.swift
//  Fitness Coach
//
//  FitPilot AI — Main tab shell shown after onboarding or when profile exists.
//

import SwiftUI

private enum AppTab: String, Hashable {
    case today
    case coach
    case journey
    case plan

    /// Legacy tab ids before Phase 6 rename. Maps to Journey / Plan.
    static let legacyTrainingTabID = "training"
    static let legacyJourneyTabID = "progress"
    static let legacyPlanTabID = "profile"

    static func fromPersistedSelection(_ raw: String?) -> AppTab {
        guard let raw else { return .today }
        switch raw {
        case legacyTrainingTabID, legacyJourneyTabID:
            return .journey
        case legacyPlanTabID:
            return .plan
        default:
            return AppTab(rawValue: raw) ?? .today
        }
    }
}

struct MainTabView: View {

    private let container: AppContainer
    private let journeyAnalyticsCoordinator: JourneyAnalyticsCoordinator
    private let weeklyProgressAnalyticsCoordinator: WeeklyProgressAnalyticsCoordinator
    private let planAnalyticsCoordinator: PlanAnalyticsCoordinator
    private let settingsAnalyticsCoordinator: SettingsAnalyticsCoordinator
    private let healthIntelligenceAnalyticsCoordinator: HealthIntelligenceAnalyticsCoordinator
    private let todayActionCoordinator: TodayActionCoordinator

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.formaResolvedTheme) private var resolvedTheme

    @StateObject private var todayModel: TodayModel
    @StateObject private var coachModel: CoachModel
    @StateObject private var journeyModel: JourneyModel
    @StateObject private var planModel: PlanModel

    @State private var selectedTab: AppTab

    init(container: AppContainer) {
        self.container = container
        self.journeyAnalyticsCoordinator = container.makeJourneyAnalyticsCoordinator()
        self.weeklyProgressAnalyticsCoordinator = container.makeWeeklyProgressAnalyticsCoordinator()
        let planAnalyticsCoordinator = container.makePlanAnalyticsCoordinator(
            weeklyProgressAnalyticsCoordinator: weeklyProgressAnalyticsCoordinator
        )
        self.planAnalyticsCoordinator = planAnalyticsCoordinator
        self.settingsAnalyticsCoordinator = container.makeSettingsAnalyticsCoordinator()
        let healthIntelligenceAnalyticsCoordinator = container.makeHealthIntelligenceAnalyticsCoordinator()
        self.healthIntelligenceAnalyticsCoordinator = healthIntelligenceAnalyticsCoordinator
        self.todayActionCoordinator = container.makeTodayActionCoordinator(
            healthIntelligenceAnalyticsCoordinator: healthIntelligenceAnalyticsCoordinator,
            weeklyProgressAnalyticsCoordinator: weeklyProgressAnalyticsCoordinator
        )
        _todayModel = StateObject(
            wrappedValue: container.makeTodayModel(
                healthIntelligenceAnalyticsCoordinator: healthIntelligenceAnalyticsCoordinator
            )
        )
        _coachModel = StateObject(
            wrappedValue: container.makeCoachModel(
                healthIntelligenceAnalyticsCoordinator: healthIntelligenceAnalyticsCoordinator
            )
        )
        _journeyModel = StateObject(
            wrappedValue: container.makeJourneyModel(
                healthIntelligenceAnalyticsCoordinator: healthIntelligenceAnalyticsCoordinator
            )
        )
        _planModel = StateObject(
            wrappedValue: container.makePlanModel(
                healthIntelligenceAnalyticsCoordinator: healthIntelligenceAnalyticsCoordinator,
                planAnalyticsCoordinator: planAnalyticsCoordinator
            )
        )
        _selectedTab = State(initialValue: Self.resolveInitialTab())
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView(
                model: todayModel,
                actionCoordinator: todayActionCoordinator,
                healthActivityQuery: container.healthActivityQueryService,
                healthIntelligenceAnalyticsCoordinator: healthIntelligenceAnalyticsCoordinator,
                onOpenCoach: { intent in
                    openCoach(with: intent)
                },
                onOpenJourney: {
                    selectedTab = .journey
                },
                onOpenPlan: {
                    selectedTab = .plan
                }
            )
            .tabItem {
                Label("Today", systemImage: "house")
            }
            .tag(AppTab.today)

            CoachView(model: coachModel, isActive: selectedTab == .coach)
                .tabItem {
                    Label("Coach", systemImage: "bubble.left.and.bubble.right")
                }
            .tag(AppTab.coach)

            JourneyView(
                model: journeyModel,
                analyticsCoordinator: journeyAnalyticsCoordinator,
                weeklyProgressAnalyticsCoordinator: weeklyProgressAnalyticsCoordinator,
                healthIntelligenceAnalyticsCoordinator: healthIntelligenceAnalyticsCoordinator,
                onOpenCoach: { prefill in
                    openCoach(with: coachLaunchIntent(fromLegacyPrefill: prefill))
                },
                onOpenPlan: {
                    selectedTab = .plan
                },
                onOpenPlanForWeeklyReview: {
                    selectedTab = .plan
                    planModel.showEditPlanFromWeeklyReview(
                        entryPoint: .journeyRecommendation
                    )
                },
                onOpenToday: {
                    selectedTab = .today
                }
            )
                .tabItem {
                    Label("Journey", systemImage: "chart.line.uptrend.xyaxis")
                }
            .tag(AppTab.journey)

            PlanView(
                model: planModel,
                healthIntelligenceAnalyticsCoordinator: healthIntelligenceAnalyticsCoordinator,
                onGoToToday: {
                    selectedTab = .today
                }
            )
                .tabItem {
                    Label("Plan", systemImage: "target")
                }
            .tag(AppTab.plan)
        }
        .tint(resolvedTheme.themePalette.primary)
        .formaThemeReactive()
        .environmentObject(container.refreshCenter)
        .environmentObject(container.trainingInsightsStore)
        .environmentObject(container.trainingInsightsModel)
        .environmentObject(container.healthSyncStateStore)
        .environmentObject(container.themeStore)
        .environmentObject(container.healthSummarySyncConsentStore)
        .environment(
            \.appleHealthSettingsEnvironment,
            AppleHealthSettingsEnvironment(
                remoteSyncService: container.healthSummarySyncService
            )
        )
        .environment(\.settingsAnalyticsCoordinator, settingsAnalyticsCoordinator)
        .environment(\.settingsPrivacyDataEnvironment, container.makeSettingsPrivacyDataEnvironment())
        #if DEBUG
        .environment(\.healthIntelligenceDebugVerification) { [container] in
            await container.verifyTodayHealthIntelligenceSnapshot()
        }
        .environment(\.accountSyncDebugActions, container.makeAccountSyncDebugActions())
        .environment(\.accountRestoreDebugActions, container.makeAccountRestoreDebugActions())
        .environment(\.coachContextDebugActions, container.makeCoachContextDebugActions())
        #endif
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                container.syncHealthCacheUserID()
                container.refreshCenter.refreshIfDayChanged()
                container.handleAccountDataSyncOnAppForeground()
                if HealthIntelligenceFeatureFlags.isSyncEnabled {
                    container.healthSyncStateStore.refreshOnAppForeground()
                }
                Task {
                    await todayModel.refresh()
                }
            }
        }
        .task {
            await bootstrapAfterEntry()
        }
        .onChange(of: selectedTab) { _, newTab in
            guard newTab == .today else { return }
            CoachTodaySyncDebugLogger.todayRefreshTriggered(
                source: "tab_return",
                refreshToken: container.refreshCenter.refreshToken
            )
            Task {
                await todayModel.refresh()
                if case .loaded(let state) = todayModel.viewState {
                    CoachTodaySyncDebugLogger.todayRefreshApplied(
                        source: "tab_return",
                        refreshToken: container.refreshCenter.refreshToken,
                        state: state
                    )
                }
            }
        }
    }

    private func bootstrapAfterEntry() async {
        container.syncHealthCacheUserID()
        await container.trainingInsightsStore.refresh()
        await todayModel.loadToday()
        await journeyModel.loadProgress()
        coachModel.refreshTodayContext()
        await planModel.refresh()
        if HealthIntelligenceFeatureFlags.isSyncEnabled {
            await container.healthSyncStateStore.refreshState()
        }
        if HealthIntelligenceFeatureFlags.healthIntelligenceEnginesEnabled {
            await container.refreshHealthIntelligenceSnapshotIfNeeded()
        }
        container.healthSyncStateStore.markForegroundBootstrapComplete()
    }

    private func openCoach(with intent: CoachLaunchIntent) {
        coachModel.launch(with: intent)
        selectedTab = .coach
    }

    private func coachLaunchIntent(fromLegacyPrefill prefill: String?) -> CoachLaunchIntent {
        guard let prefill, !prefill.isEmpty else { return .normal }
        if prefill == TodayCoachPrompt.scanFood {
            return .analyzePhotoMeal()
        }
        if prefill == TodayCoachPrompt.logWater {
            return .logWater(amountMl: 500)
        }
        if isMealLoggingPrefill(prefill) {
            return .logMeal(mealType: TodayNextActionFormatting.mealType(from: prefill))
        }
        return .prefill(prefill)
    }

    private func isMealLoggingPrefill(_ prefill: String) -> Bool {
        [
            TodayCoachPrompt.logMeal(),
            TodayCoachPrompt.logMeal(.breakfast),
            TodayCoachPrompt.logMeal(.lunch),
            TodayCoachPrompt.logMeal(.dinner),
            TodayCoachPrompt.logMeal(.snack)
        ].contains(prefill)
    }

    // MARK: - Tab selection

    private static let selectedTabStorageKey = "forma.mainTab.selectedTab"

    /// Training was removed from the tab bar; open Training Insights from Today, Plan, or Journey.
    private static func resolveInitialTab() -> AppTab {
        let persisted = UserDefaults.standard.string(forKey: selectedTabStorageKey)
        let destination = OnboardingCompletionPolicy.initialMainTab(persistedTabRawValue: persisted)
        if persisted == AppTab.legacyTrainingTabID || persisted == AppTab.legacyJourneyTabID {
            UserDefaults.standard.set(AppTab.journey.rawValue, forKey: selectedTabStorageKey)
        } else if persisted == AppTab.legacyPlanTabID {
            UserDefaults.standard.set(AppTab.plan.rawValue, forKey: selectedTabStorageKey)
        }
        return AppTab.fromPersistedSelection(destination.rawValue)
    }
}

#Preview {
    let container = try! AppContainer(inMemory: true)
    MainTabView(container: container)
        .environmentObject(container.authManager)
        .environmentObject(container.trainingInsightsStore)
        .environmentObject(container.trainingInsightsModel)
        .environmentObject(container.themeStore)
        .formaThemePreview()
}
