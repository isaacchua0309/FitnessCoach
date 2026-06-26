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

    init(model: ProgressModel) {
        self.model = model
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
                JourneyTransformationHeroSection(state: state.transformation)

                if !state.milestones.isEmpty {
                    JourneyMilestonesSection(milestones: state.milestones)
                }

                JourneyWeeklySnapshotSection(snapshot: state.weeklySnapshot)

                JourneyCoachInsightsSection(insights: state.coachInsights)

                JourneyConsistencyCalendarSection(calendar: state.consistencyCalendar)

                JourneyAchievementsSection(achievements: state.achievements)

                JourneyWeightTrendSection(state: state.weightTrend)

                JourneyDetailedAnalyticsSection(
                    analytics: state.analytics,
                    selectedRangeDays: state.selectedRangeDays
                ) { days in
                    Task { await model.selectRange(days: days) }
                }
            }
            .padding(.horizontal, JourneyLayout.horizontalPadding)
            .padding(.top, FormaTokens.Spacing.md)
            .padding(.bottom, FormaTokens.Spacing.sm)
        }
        .fitPilotScrollBottomInset()
    }
}

#Preview {
    let container = try! AppContainer(inMemory: true)
    ProgressView(model: container.makeProgressModel())
        .environmentObject(container.refreshCenter)
}
