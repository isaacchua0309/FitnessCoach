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

    let analyticsCoordinator: JourneyAnalyticsCoordinator

    /// Optional prefill text for Coach input. `nil` opens Coach without prefilling.
    var onOpenCoach: ((String?) -> Void)?
    /// Opens the Plan tab for goal edits or Apple Health connection.
    var onOpenPlan: (() -> Void)?

    init(
        model: JourneyModel,
        analyticsCoordinator: JourneyAnalyticsCoordinator,
        onOpenCoach: ((String?) -> Void)? = nil,
        onOpenPlan: (() -> Void)? = nil
    ) {
        self.model = model
        self.analyticsCoordinator = analyticsCoordinator
        self.onOpenCoach = onOpenCoach
        self.onOpenPlan = onOpenPlan
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Journey")
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
                    await model.refresh()
                }
                .background(FormaTokens.Color.canvas)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.viewState {
        case .loading:
            FormaScreenLoadingView(message: FormaProductCopy.Loading.journey)
        case .empty:
            JourneyEmptyStateView {
                Task { await model.refresh() }
            }
            .onAppear {
                syncAnalyticsContextForEmpty()
                analyticsCoordinator.logScreenViewed()
            }
        case .error(let message):
            FormaScreenErrorView(message: message, onRetry: {
                Task { await model.refresh() }
            }, style: .tabRoot)
        case .loaded(let state):
            dashboard(state)
        }
    }

    private func dashboard(_ state: JourneyDashboardState) -> some View {
        ScrollView {
            JourneyDashboardContent(
                state: state,
                analyticsCoordinator: analyticsCoordinator,
                onCTA: handleCTA,
                onSelectRange: { days in
                    analyticsCoordinator.logRangeChanged(days: days)
                    Task { await model.selectRange(days: days) }
                },
                onAnalyticsExpanded: {
                    analyticsCoordinator.logAnalyticsExpanded()
                }
            )
        }
        .formaMainTabScrollInsets()
        .accessibilityIdentifier("journey-scroll")
        .onAppear {
            syncAnalyticsContext(for: state)
            analyticsCoordinator.logScreenViewed()
        }
        .onChange(of: state.selectedRangeDays) { _, _ in
            syncAnalyticsContext(for: state)
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

#Preview("Strong momentum") {
    let container = try! AppContainer(inMemory: true)
    JourneyView(
        model: JourneyModel.preview(scenario: .strongMomentum),
        analyticsCoordinator: container.makeJourneyAnalyticsCoordinator()
    )
    .environmentObject(container.refreshCenter)
    .environmentObject(container.trainingInsightsStore)
}

#Preview("Plateau") {
    let container = try! AppContainer(inMemory: true)
    JourneyView(
        model: JourneyModel.preview(scenario: .plateau),
        analyticsCoordinator: container.makeJourneyAnalyticsCoordinator()
    )
    .environmentObject(container.refreshCenter)
    .environmentObject(container.trainingInsightsStore)
}
