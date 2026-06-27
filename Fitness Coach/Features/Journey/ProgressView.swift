//
//  ProgressView.swift
//  Fitness Coach
//
//  FitPilot AI — Journey: am I becoming healthier?
//

import SwiftUI

struct ProgressView: View {

    @ObservedObject var model: ProgressModel
    @EnvironmentObject private var refreshCenter: AppRefreshCenter

    /// Optional prefill text for Coach input. `nil` opens Coach without prefilling.
    var onOpenCoach: ((String?) -> Void)?

    init(model: ProgressModel, onOpenCoach: ((String?) -> Void)? = nil) {
        self.model = model
        self.onOpenCoach = onOpenCoach
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
                .preferredColorScheme(.dark)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.viewState {
        case .loading:
            ProgressLoadingView()
        case .empty:
            ProgressEmptyStateView {
                Task { await model.refresh() }
            }
        case .error(let message):
            ProgressErrorView(message: message) {
                Task { await model.refresh() }
            }
        case .loaded(let state):
            dashboard(state)
        }
    }

    private func dashboard(_ state: ProgressDashboardState) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: JourneyLayout.sectionSpacing) {
                JourneyTransformationHeroSection(
                    state: state.transformation,
                    milestones: state.milestones
                )

                if let coachMessage = coachInsightMessage(for: state) {
                    JourneyCoachInsightsSection(message: coachMessage)
                }

                if !state.milestones.isEmpty {
                    JourneyMilestonesSection(milestones: state.milestones)
                }

                JourneyWeeklySnapshotSection(snapshot: state.weeklySnapshot)

                JourneyConsistencyCalendarSection(calendar: state.consistencyCalendar)

                JourneyWeightTrendSection(state: state.weightTrend) {
                    onOpenCoach?(TodayCoachPrompt.logWeight)
                }

                JourneyDetailedAnalyticsSection(
                    analytics: state.analytics,
                    weeklySnapshot: state.weeklySnapshot,
                    selectedRangeDays: state.selectedRangeDays
                ) { days in
                    Task { await model.selectRange(days: days) }
                }
            }
            .padding(.horizontal, JourneyLayout.horizontalPadding)
            .padding(.top, FormaTokens.Spacing.md)
            .padding(.bottom, JourneyLayout.scrollBottomContentPadding)
        }
        .journeyScrollBottomInset()
    }

    private func coachInsightMessage(for state: ProgressDashboardState) -> String? {
        if let insight = state.coachInsights.first?.message, !insight.isEmpty {
            return insight
        }
        if state.transformation.currentPhase == "Getting started" {
            return FormaProductCopy.Journey.coachInsightGettingStarted
        }
        return FormaProductCopy.Journey.coachInsightFallback
    }
}

#Preview {
    let container = try! AppContainer(inMemory: true)
    ProgressView(model: container.makeProgressModel())
        .environmentObject(container.refreshCenter)
        .environmentObject(container.trainingInsightsStore)
}
