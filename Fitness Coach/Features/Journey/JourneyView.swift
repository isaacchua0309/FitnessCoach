//
//  JourneyView.swift
//  Fitness Coach
//
//  FitPilot AI — Journey: your fitness story.
//

import SwiftUI

@MainActor
struct JourneyView: View {

    @ObservedObject var model: JourneyModel
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.theme) private var theme
    @EnvironmentObject private var refreshCenter: AppRefreshCenter
    @EnvironmentObject private var trainingInsightsStore: TrainingInsightsStore
    @State private var presentedWeeklyReviewDetail: WeeklyReviewDetailPresentation?

    let analyticsCoordinator: JourneyAnalyticsCoordinator
    let weeklyProgressAnalyticsCoordinator: WeeklyProgressAnalyticsCoordinator?
    let healthIntelligenceAnalyticsCoordinator: HealthIntelligenceAnalyticsCoordinator?

    /// Optional prefill text for Coach input. `nil` opens Coach without prefilling.
    var onOpenCoach: ((String?) -> Void)?
    /// Opens the Plan tab for goal edits or Apple Health connection.
    var onOpenPlan: (() -> Void)?
    /// Opens Plan review flow with weekly recommendation context (no auto-apply).
    var onOpenPlanForWeeklyReview: (() -> Void)?
    /// Opens the Today tab for daily logging actions.
    var onOpenToday: (() -> Void)?

    init(
        model: JourneyModel,
        analyticsCoordinator: JourneyAnalyticsCoordinator,
        weeklyProgressAnalyticsCoordinator: WeeklyProgressAnalyticsCoordinator? = nil,
        healthIntelligenceAnalyticsCoordinator: HealthIntelligenceAnalyticsCoordinator? = nil,
        onOpenCoach: ((String?) -> Void)? = nil,
        onOpenPlan: (() -> Void)? = nil,
        onOpenPlanForWeeklyReview: (() -> Void)? = nil,
        onOpenToday: (() -> Void)? = nil
    ) {
        self.model = model
        self.analyticsCoordinator = analyticsCoordinator
        self.weeklyProgressAnalyticsCoordinator = weeklyProgressAnalyticsCoordinator
        self.healthIntelligenceAnalyticsCoordinator = healthIntelligenceAnalyticsCoordinator
        self.onOpenCoach = onOpenCoach
        self.onOpenPlan = onOpenPlan
        self.onOpenPlanForWeeklyReview = onOpenPlanForWeeklyReview
        self.onOpenToday = onOpenToday
    }

    var body: some View {
        let _ = themeManager.themeRevision
        return NavigationStack {
            content
                .navigationTitle(FormaProductCopy.Journey.Header.title)
                .task {
                    await model.loadProgress()
                }
                .onChange(of: refreshCenter.refreshToken) { _, _ in
                    Task { await model.refresh() }
                }
                .onAppear {
                    if case .loaded = model.viewState {
                        Task { await model.refresh() }
                    }
                }
                .refreshable {
                    await performPullToRefresh()
                }
                .background(theme.appBackground)
                .formaThemeReactive()
                .sheet(item: $presentedWeeklyReviewDetail) { presentation in
                    NavigationStack {
                        WeeklyReviewDetailView(
                            detail: presentation.detail,
                            weeklyProgressAnalyticsCoordinator: weeklyProgressAnalyticsCoordinator,
                            onPrimaryCTA: handleWeeklyProgressCTA,
                            onSecondaryCTA: handleWeeklyProgressCTA
                        )
                        .navigationTitle(FormaProductCopy.WeeklyReviewPresentation.sectionTitle)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button(FormaProductCopy.Common.done) {
                                    weeklyProgressAnalyticsCoordinator?.logReviewCompleted(
                                        summary: presentation.detail.summary
                                    )
                                    presentedWeeklyReviewDetail = nil
                                }
                            }
                        }
                    }
                    .background(FormaTokens.Color.canvas)
                    .formaThemeReactive()
                    .onAppear {
                        healthIntelligenceAnalyticsCoordinator?.logWeeklyReviewDetailOpened()
                        weeklyProgressAnalyticsCoordinator?.logReviewOpened(
                            summary: presentation.detail.summary
                        )
                    }
                }
        }
    }

    private func performPullToRefresh() async {
        await model.performManualCrossDeviceRefresh()
        await model.refresh(forceWeeklyReviewRefresh: true)
    }

    @ViewBuilder
    private var content: some View {
        switch model.viewState {
        case .loading:
            FormaScreenLoadingView(message: FormaProductCopy.Loading.journey)
        case .empty:
            JourneyEmptyStateView {
                analyticsCoordinator.logGoToTodayTapped()
                onOpenToday?()
            }
            .onAppear {
                syncAnalyticsContextForEmpty()
                analyticsCoordinator.logViewed()
            }
        case .error(let message):
            FormaScreenErrorView(message: message, onRetry: {
                Task { await model.refresh() }
            }, style: .tabRoot)
        case .pendingAccountRestore(let message):
            AccountRestorePendingStateView(message: message)
                .onAppear {
                    weeklyProgressAnalyticsCoordinator?.logRestorePending()
                }
        case .loaded(let state):
            dashboard(state)
        }
    }

    private var healthIntelligenceUIEnabled: Bool {
        HealthIntelligenceFeatureFlags.isUIEnabled
    }

    private func dashboard(_ state: JourneyDashboardState) -> some View {
        ScrollView {
            JourneyDashboardContent(
                state: state,
                healthIntelligenceUIEnabled: healthIntelligenceUIEnabled,
                healthIntelligenceSectionState: healthIntelligenceUIEnabled
                    ? model.journeyHealthIntelligenceSectionState
                    : nil,
                analyticsCoordinator: analyticsCoordinator,
                weeklyProgressAnalyticsCoordinator: weeklyProgressAnalyticsCoordinator,
                healthIntelligenceAnalyticsCoordinator: healthIntelligenceAnalyticsCoordinator,
                onCTA: handleCTA,
                onWeeklyProgressCTA: handleWeeklyProgressCTA,
                onGoToToday: { onOpenToday?() },
                onConnectHealth: healthIntelligenceUIEnabled ? {
                    healthIntelligenceAnalyticsCoordinator?.logHealthPermissionCTATapped(surface: .journey)
                    onOpenPlan?()
                } : nil,
                onOpenWeeklyProgressDetail: {
                    presentedWeeklyReviewDetail = WeeklyReviewDetailPresentation(
                        detail: UnifiedWeeklyReviewPresentationBuilder.buildDetail(
                            dashboard: state,
                            healthIntelligence: healthIntelligenceUIEnabled
                                ? model.journeyHealthIntelligenceSectionState
                                : nil,
                            freshnessInput: model.weeklyProgressFreshnessInput
                        )
                    )
                },
                weeklyProgressFreshnessInput: model.weeklyProgressFreshnessInput
            )
        }
        .formaMainTabScrollInsets()
        .overlay(alignment: .top) {
            if model.isCrossDeviceRefreshing {
                ProgressView()
                    .controlSize(.small)
                    .padding(.horizontal, FormaTokens.Spacing.md)
                    .padding(.vertical, FormaTokens.Spacing.sm)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(.top, FormaTokens.Spacing.sm)
                    .accessibilityLabel("Syncing latest updates")
            }
        }
        .accessibilityIdentifier("journey-scroll")
        .onAppear {
            syncAnalyticsContext(for: state)
            analyticsCoordinator.logViewed()
            weeklyProgressAnalyticsCoordinator?.updateContext(from: state.weeklyProgressSummary)
        }
    }

    private func handleCTA(_ cta: JourneyCTA) {
        analyticsCoordinator.logCTATapped(cta)
        JourneyCTAHandler.perform(cta, onOpenCoach: onOpenCoach, onOpenPlan: onOpenPlan)
    }

    private func handleWeeklyProgressCTA(_ cta: WeeklyProgressCTA) {
        if cta.kind == .reviewPlan, case .loaded(let state) = model.viewState {
            let unified = UnifiedWeeklyReviewPresentationBuilder.build(
                dashboard: state,
                healthIntelligence: healthIntelligenceUIEnabled
                    ? model.journeyHealthIntelligenceSectionState
                    : nil,
                freshnessInput: model.weeklyProgressFreshnessInput
            )
            weeklyProgressAnalyticsCoordinator?.logPlanRecommendationTapped(
                summary: state.weeklyProgressSummary,
                recommendationKind: unified.planRecommendationBlock?.recommendationKind,
                surface: presentedWeeklyReviewDetail == nil ? .journeyCard : .journeyDetail,
                entryPoint: presentedWeeklyReviewDetail == nil ? .journeyCard : .journeyDetail
            )
        }

        WeeklyProgressCTAHandler.perform(
            cta,
            onOpenToday: onOpenToday,
            onOpenPlan: onOpenPlan,
            onOpenPlanForWeeklyReview: onOpenPlanForWeeklyReview,
            onOpenCoach: onOpenCoach
        )
    }

    private func syncAnalyticsContext(for state: JourneyDashboardState) {
        analyticsCoordinator.updateContext(
            from: state,
            healthConnected: trainingInsightsStore.integrationState.isConnected
        )
    }

    private func syncAnalyticsContextForEmpty() {
        analyticsCoordinator.updateContextForEmptyProfile(
            healthConnected: trainingInsightsStore.integrationState.isConnected
        )
    }
}

#Preview("New user") {
    let container = try! AppContainer(inMemory: true)
    JourneyView(
        model: JourneyModel.preview(scenario: .brandNewUser),
        analyticsCoordinator: container.makeJourneyAnalyticsCoordinator()
    )
    .environmentObject(container.refreshCenter)
    .environmentObject(container.trainingInsightsStore)
}

#Preview("Week 1 user") {
    let container = try! AppContainer(inMemory: true)
    JourneyView(
        model: JourneyModel.preview(scenario: .weekOne),
        analyticsCoordinator: container.makeJourneyAnalyticsCoordinator()
    )
    .environmentObject(container.refreshCenter)
    .environmentObject(container.trainingInsightsStore)
}

#Preview("Weight loss user") {
    let container = try! AppContainer(inMemory: true)
    JourneyView(
        model: JourneyModel.preview(scenario: .strongMomentum),
        analyticsCoordinator: container.makeJourneyAnalyticsCoordinator()
    )
    .environmentObject(container.refreshCenter)
    .environmentObject(container.trainingInsightsStore)
}

#Preview("Highly consistent user") {
    let container = try! AppContainer(inMemory: true)
    JourneyView(
        model: JourneyModel.preview(scenario: .highlyConsistent),
        analyticsCoordinator: container.makeJourneyAnalyticsCoordinator()
    )
    .environmentObject(container.refreshCenter)
    .environmentObject(container.trainingInsightsStore)
}

#Preview("Insufficient data user") {
    let container = try! AppContainer(inMemory: true)
    JourneyView(
        model: JourneyModel.preview(scenario: .sparseData),
        analyticsCoordinator: container.makeJourneyAnalyticsCoordinator()
    )
    .environmentObject(container.refreshCenter)
    .environmentObject(container.trainingInsightsStore)
}

#Preview("Health Intelligence enabled") {
    let container = try! AppContainer(inMemory: true)
    JourneyView(
        model: JourneyModel.preview(scenario: .strongMomentum),
        analyticsCoordinator: container.makeJourneyAnalyticsCoordinator()
    )
    .environmentObject(container.refreshCenter)
    .environmentObject(container.trainingInsightsStore)
    .formaThemePreview(palette: .blossomPink)
}
