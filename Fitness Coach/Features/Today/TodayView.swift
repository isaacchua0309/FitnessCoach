//
//  TodayView.swift
//  Fitness Coach
//
//  FitPilot AI — Today Mission Control. Native actions via TodayActionCoordinator; Coach when required.
//

import SwiftUI

struct TodayView: View {

    @ObservedObject var model: TodayModel
    @StateObject private var actionCoordinator: TodayActionCoordinator
    @EnvironmentObject private var trainingInsightsStore: TrainingInsightsStore
    @EnvironmentObject private var trainingInsightsModel: TrainingInsightsModel
    @EnvironmentObject private var healthSyncStateStore: HealthSyncStateStore
    @EnvironmentObject private var refreshCenter: AppRefreshCenter
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let healthActivityQuery: HealthActivityQueryService
    private let healthIntelligenceAnalyticsCoordinator: HealthIntelligenceAnalyticsCoordinator?

    @State private var appleHealthWorkoutCount: Int?
    @State private var appleHealthStepsToday: Int?
    @State private var isShowingTrainingInsights = false

    /// Opens Coach with a launch intent when an action requires conversational AI.
    var onOpenCoach: ((CoachLaunchIntent) -> Void)?
    var onOpenJourney: (() -> Void)?
    var onOpenPlan: (() -> Void)?

    init(
        model: TodayModel,
        actionCoordinator: TodayActionCoordinator,
        healthActivityQuery: HealthActivityQueryService,
        healthIntelligenceAnalyticsCoordinator: HealthIntelligenceAnalyticsCoordinator? = nil,
        onOpenCoach: ((CoachLaunchIntent) -> Void)? = nil,
        onOpenJourney: (() -> Void)? = nil,
        onOpenPlan: (() -> Void)? = nil
    ) {
        self.model = model
        _actionCoordinator = StateObject(wrappedValue: actionCoordinator)
        self.healthActivityQuery = healthActivityQuery
        self.healthIntelligenceAnalyticsCoordinator = healthIntelligenceAnalyticsCoordinator
        self.onOpenCoach = onOpenCoach
        self.onOpenJourney = onOpenJourney
        self.onOpenPlan = onOpenPlan
    }

    var body: some View {
        NavigationStack {
            content
                .navigationBarTitleDisplayMode(.inline)
                .toolbar(.hidden, for: .navigationBar)
                .task {
                    await trainingInsightsStore.refresh()
                    await model.loadToday(activityContext: currentActivityContext)
                }
                .onChange(of: authManager.authState) { _, _ in
                    Task<Void, Never> {
                        await trainingInsightsStore.refresh()
                        await model.loadToday(activityContext: currentActivityContext)
                    }
                }
                .onChange(of: refreshCenter.refreshToken) { _, newToken in
                    CoachTodaySyncDebugLogger.todayRefreshTriggered(
                        source: "refresh_token",
                        refreshToken: newToken
                    )
                    Task<Void, Never> {
                        await refreshDashboard(triggerSource: "refresh_token")
                    }
                }
                .onAppear {
                    wireActionCoordinator()
                    if case .loaded = model.viewState {
                        Task<Void, Never> {
                            await refreshDashboard()
                        }
                    }
                }
                .refreshable {
                    await performPullToRefresh()
                }
                .sheet(item: $actionCoordinator.presentedDailyReview) { review in
                    TodayDailyReviewSheet(
                        review: review,
                        title: FormaProductCopy.Today.YesterdayReview.sectionTitle,
                        onDismiss: {
                            actionCoordinator.dismissDailyReviewSheet()
                        }
                    )
                }
                .sheet(isPresented: $isShowingTrainingInsights) {
                    TrainingInsightsView(
                        insightsStore: trainingInsightsStore,
                        insightsModel: trainingInsightsModel
                    )
                    .environmentObject(refreshCenter)
                }
                .sheet(isPresented: $actionCoordinator.isPresentingLogWeightSheet) {
                    TodayLogWeightSheet(
                        errorMessage: actionCoordinator.lastErrorMessage,
                        onSave: { actionCoordinator.saveWeight($0) }
                    )
                }
                .sheet(item: $actionCoordinator.editFoodPresentation) { presentation in
                    TodayEditFoodEntrySheet(
                        entry: presentation.entry,
                        errorMessage: actionCoordinator.foodEditErrorMessage,
                        onSave: { actionCoordinator.saveFoodEdit(from: $0) },
                        onDelete: {
                            actionCoordinator.requestDeleteFood(presentation.entry)
                        },
                        onCancel: {
                            actionCoordinator.dismissEditFoodSheet()
                        }
                    )
                }
                .confirmationDialog(
                    FormaProductCopy.Today.Meals.deleteConfirmationTitle,
                    isPresented: deleteConfirmationBinding,
                    titleVisibility: .visible
                ) {
                    Button(
                        FormaProductCopy.Today.Meals.deleteConfirmAction,
                        role: .destructive
                    ) {
                        actionCoordinator.confirmDeleteFood()
                    }
                    Button(FormaProductCopy.Today.Meals.deleteCancelAction, role: .cancel) {
                        actionCoordinator.cancelDeleteFood()
                    }
                } message: {
                    Text(FormaProductCopy.Today.Meals.deleteConfirmationMessage)
                }
                .background(theme.appBackground)
                .overlay(alignment: .bottom) {
                    if let feedback = actionCoordinator.snackbarMessage {
                        FormaTransientBanner(
                            message: feedback.message,
                            style: feedback.style == .success ? .success : .error
                        )
                        .padding(.bottom, FormaTokens.Spacing.md)
                        .transition(
                            reduceMotion
                                ? .opacity
                                : .move(edge: .bottom).combined(with: .opacity)
                        )
                    }
                }
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: actionCoordinator.snackbarMessage)
                .onChange(of: actionCoordinator.snackbarMessage) { _, feedback in
                    guard let feedback else { return }
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: feedback.autoDismissNanoseconds)
                        if actionCoordinator.snackbarMessage == feedback {
                            actionCoordinator.clearSnackbar()
                        }
                    }
                }
                .formaThemeReactive()
                .todayLiveTheme()
        }
    }

    private var deleteConfirmationBinding: Binding<Bool> {
        Binding(
            get: { actionCoordinator.pendingDeleteFoodEntry != nil },
            set: { isPresented in
                if !isPresented {
                    actionCoordinator.cancelDeleteFood()
                }
            }
        )
    }

    private func wireActionCoordinator() {
        actionCoordinator.onOpenCoach = { intent in
            onOpenCoach?(intent)
        }
        actionCoordinator.onOpenTrainingInsights = {
            isShowingTrainingInsights = true
        }
        actionCoordinator.onRefreshHealthData = {
            healthSyncStateStore.syncToday()
        }
    }

    private func performPullToRefresh() async {
        await model.performManualCrossDeviceRefresh()
        await refreshDashboard(triggerSource: "pull_to_refresh")
    }

    private func refreshDashboard(triggerSource: String? = nil) async {
        await trainingInsightsStore.refresh()
        if trainingInsightsStore.integrationState.isConnected {
            appleHealthWorkoutCount = await healthActivityQuery.workoutCountToday()
            appleHealthStepsToday = try? await healthActivityQuery.stepsToday()
        } else {
            appleHealthWorkoutCount = nil
            appleHealthStepsToday = nil
        }
        await model.refresh(activityContext: currentActivityContext)
        if case .loaded(let state) = model.viewState {
            syncAnalyticsContext(for: state)
            if let triggerSource {
                CoachTodaySyncDebugLogger.todayRefreshApplied(
                    source: triggerSource,
                    refreshToken: refreshCenter.refreshToken,
                    state: state
                )
            }
        }
    }

    private var currentActivityContext: TodayActivityContext {
        TodayActivityContext(
            trainingIntegration: trainingInsightsStore.integrationState,
            trainingDataSource: trainingInsightsStore.dataSource,
            appleHealthWorkoutCount: appleHealthWorkoutCount,
            stepsToday: appleHealthStepsToday
        )
    }

    @ViewBuilder
    private var content: some View {
        switch model.viewState {
        case .loading:
            MainTabPageScaffold(
                title: FormaProductCopy.Today.Header.title
            ) {
                TodayDashboardSkeletonView()
            }
        case .empty:
            MainTabPageScaffold(
                title: FormaProductCopy.Today.Header.title,
                scrollMode: .embedded
            ) {
                TodayEmptyStateView {
                    onOpenPlan?()
                }
            }
        case .error(let message):
            MainTabPageScaffold(
                title: FormaProductCopy.Today.Header.title,
                scrollMode: .embedded
            ) {
                FormaScreenErrorView(message: message, onRetry: {
                    Task { await refreshDashboard() }
                }, style: .tabRoot)
            }
        case .pendingAccountRestore(let message):
            MainTabPageScaffold(
                title: FormaProductCopy.Today.Header.title,
                scrollMode: .embedded,
                reservesTabBarScrollInset: false
            ) {
                AccountRestorePendingStateView(message: message)
            }
        case .loaded(let state):
            dashboard(state)
        }
    }

    private var isHealthIntelligenceUIEnabled: Bool {
        HealthIntelligenceFeatureFlags.isUIEnabled
    }

    private func dashboard(_ state: TodayDashboardState) -> some View {
        let _ = themeManager.themeRevision
        return MainTabPageScaffold(
            title: FormaProductCopy.Today.Header.title,
            subtitle: TodayDashboardHeaderFormatting.dateLine(for: state.date),
            sectionSpacing: TodayLayout.sectionSpacing,
            showsCrossDeviceRefreshBanner: model.isCrossDeviceRefreshing,
            trailingAction: {
                if let planStatusChip = TodayDashboardHeaderFormatting.planStatusChip(for: state.mission.status) {
                    PageActionPill(title: planStatusChip)
                }
            }
        ) {
            TodayReadOnlyView(
                state: state,
                actionCoordinator: actionCoordinator,
                healthIntelligenceSection: isHealthIntelligenceUIEnabled
                    ? model.healthIntelligenceSectionState
                    : nil,
                isHealthIntelligenceUIEnabled: isHealthIntelligenceUIEnabled,
                healthIntelligenceAnalyticsCoordinator: healthIntelligenceAnalyticsCoordinator,
                onHealthNextBestAction: { destination in
                    actionCoordinator.handleHealthNextBestAction(destination)
                },
                onOpenJourney: {
                    onOpenJourney?()
                },
                onOpenPlan: {
                    onOpenPlan?()
                }
            )
        }
        .onAppear {
            syncAnalyticsContext(for: state)
            actionCoordinator.logTodayViewed()
        }
        .onChange(of: state.date) { _, _ in
            syncAnalyticsContext(for: state)
        }
        .todayLiveTheme()
    }

    private func syncAnalyticsContext(for state: TodayDashboardState) {
        actionCoordinator.updateAnalyticsContext(
            from: state,
            healthConnected: trainingInsightsStore.integrationState.isConnected
        )
    }
}

#Preview {
    let container = try! AppContainer(inMemory: true)
    TodayView(
        model: container.makeTodayModel(),
        actionCoordinator: container.makeTodayActionCoordinator(),
        healthActivityQuery: container.healthActivityQueryService
    )
    .environmentObject(container.refreshCenter)
    .environmentObject(container.authManager)
    .environmentObject(container.trainingInsightsStore)
    .environmentObject(container.trainingInsightsModel)
    .environmentObject(container.themeStore)
    .formaThemePreview()
}

#if DEBUG
/// Preview harness that switches palette while Today remains visible — use to verify live card chrome updates.
#Preview("Theme toggle stress") {
  LiveThemeDebugHarness.shell(title: "Today") { _ in
    ScrollView {
      TodayReadOnlyView(
        state: TodayPreviewData.state,
        actionCoordinator: TodayReadOnlyPreviewSupport.coordinator(),
        healthIntelligenceSection: TodayHealthIntelligencePreviewData.workoutDay,
        isHealthIntelligenceUIEnabled: true,
        onHealthNextBestAction: { _ in }
      )
      .padding(.horizontal, TodayLayout.horizontalPadding)
      .padding(.vertical, FormaTokens.Spacing.md)
    }
    .formaMainTabScrollInsets()
    .background(FormaTokens.Color.canvas)
  }
}
#endif
