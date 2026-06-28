//
//  ProgressView.swift
//  Fitness Coach
//
//  FitPilot AI — Journey: your fitness story.
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
            FormaScreenLoadingView(message: FormaProductCopy.Loading.journey)
        case .empty:
            ProgressEmptyStateView {
                Task { await model.refresh() }
            }
        case .error(let message):
            FormaScreenErrorView(message: message, onRetry: {
                Task { await model.refresh() }
            }, style: .tabRoot)
        case .loaded(let state):
            dashboard(state)
        }
    }

    private func dashboard(_ state: ProgressDashboardState) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: JourneyLayout.sectionSpacing) {
                JourneyTransformationHeroSection(state: state.transformation)

                JourneyWeeklySnapshotSection(review: state.weeklyReview)

                if !state.milestones.items.isEmpty {
                    JourneyMilestonesSection(milestones: state.milestones.items)
                }

                JourneyCoachInsightsSection(message: state.habitInsights.habitInsightExplanation)

                JourneyCoachInsightsSection(message: state.progressAttribution.primaryReason)

                JourneyConsistencyCalendarSection(calendar: state.monthlyRecap.calendar) {
                    onOpenCoach?(nil)
                }

                JourneyAchievementsSection(records: state.personalRecords)

                JourneyDetailedAnalyticsSection(
                    analytics: state.detailedAnalytics,
                    weeklyReview: state.weeklyReview,
                    selectedRangeDays: state.selectedRangeDays
                ) { days in
                    Task { await model.selectRange(days: days) }
                }
            }
            .padding(.horizontal, JourneyLayout.horizontalPadding)
            .padding(.top, FormaTokens.Spacing.md)
            .padding(.bottom, JourneyLayout.scrollBottomContentPadding)
        }
        .formaMainTabScrollInsets()
    }
}

#Preview {
    let container = try! AppContainer(inMemory: true)
    ProgressView(model: container.makeProgressModel())
        .environmentObject(container.refreshCenter)
        .environmentObject(container.trainingInsightsStore)
}
