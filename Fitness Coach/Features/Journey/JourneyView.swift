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
    @EnvironmentObject private var refreshCenter: AppRefreshCenter
    @EnvironmentObject private var trainingInsightsStore: TrainingInsightsStore
    @State private var presentedWeeklyReviewDetail: WeeklyReviewDetailPresentation?

    let analyticsCoordinator: JourneyAnalyticsCoordinator

    /// Optional prefill text for Coach input. `nil` opens Coach without prefilling.
    var onOpenCoach: ((String?) -> Void)?
    /// Opens the Plan tab for goal edits or Apple Health connection.
    var onOpenPlan: (() -> Void)?
    /// Opens the Today tab for daily logging actions.
    var onOpenToday: (() -> Void)?

    init(
        model: JourneyModel,
        analyticsCoordinator: JourneyAnalyticsCoordinator,
        onOpenCoach: ((String?) -> Void)? = nil,
        onOpenPlan: (() -> Void)? = nil,
        onOpenToday: (() -> Void)? = nil
    ) {
        self.model = model
        self.analyticsCoordinator = analyticsCoordinator
        self.onOpenCoach = onOpenCoach
        self.onOpenPlan = onOpenPlan
        self.onOpenToday = onOpenToday
    }

    var body: some View {
        NavigationStack {
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
                    await model.refresh(forceWeeklyReviewRefresh: true)
                }
                .background(FormaTokens.Color.canvas)
                .sheet(item: $presentedWeeklyReviewDetail) { presentation in
                    NavigationStack {
                        WeeklyReviewDetailView(state: presentation.state)
                            .navigationTitle(FormaProductCopy.WeeklyReviewPresentation.sectionTitle)
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button(FormaProductCopy.Common.done) {
                                        presentedWeeklyReviewDetail = nil
                                    }
                                }
                            }
                    }
                    .background(FormaTokens.Color.canvas)
                    .formaThemeReactive()
                }
        }
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
                onCTA: handleCTA,
                onGoToToday: { onOpenToday?() },
                onConnectHealth: healthIntelligenceUIEnabled ? { onOpenPlan?() } : nil,
                onWeeklyReviewSelected: { detail in
                    presentedWeeklyReviewDetail = WeeklyReviewDetailPresentation(state: detail)
                }
            )
        }
        .formaMainTabScrollInsets()
        .accessibilityIdentifier("journey-scroll")
        .onAppear {
            syncAnalyticsContext(for: state)
            analyticsCoordinator.logViewed()
        }
    }

    private func handleCTA(_ cta: JourneyCTA) {
        analyticsCoordinator.logCTATapped(cta)
        JourneyCTAHandler.perform(cta, onOpenCoach: onOpenCoach, onOpenPlan: onOpenPlan)
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
