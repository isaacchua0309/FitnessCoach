//
//  TodayView.swift
//  Fitness Coach
//
//  FitPilot AI — Read-only daily status. Answers: "Am I on track today?"
//
//  All logging and updates route to Coach via onOpenCoach.
//  Production sync: pull-to-refresh, AppRefreshCenter after Coach logs, and onAppear reload.
//

import SwiftUI

struct TodayView: View {

    @ObservedObject var model: TodayModel
    @EnvironmentObject private var trainingInsightsStore: TrainingInsightsStore
    @EnvironmentObject private var trainingInsightsModel: TrainingInsightsModel
    @EnvironmentObject private var refreshCenter: AppRefreshCenter

    @State private var appleHealthWorkoutCount: Int?
    @State private var isShowingTrainingInsights = false

    /// Optional prefill text for Coach input. `nil` opens Coach without prefilling.
    var onOpenCoach: ((String?) -> Void)?

    init(model: TodayModel, onOpenCoach: ((String?) -> Void)? = nil) {
        self.model = model
        self.onOpenCoach = onOpenCoach
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Today")
                .toolbar {
                    #if DEBUG
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            Task { await refreshDashboard() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(FormaTokens.Typography.caption)
                                .foregroundStyle(FormaTokens.Color.textTertiary)
                        }
                        .accessibilityLabel(FormaProductCopy.Today.syncAccessibilityLabel)
                        .accessibilityHint(FormaProductCopy.Today.syncAccessibilityHint)
                    }
                    #endif
                }
                .task {
                    await trainingInsightsStore.refresh()
                    await model.loadToday()
                }
                .onChange(of: refreshCenter.refreshToken) { _, _ in
                    Task<Void, Never> {
                        await refreshDashboard()
                    }
                }
                .onAppear {
                    if case .loaded = model.viewState {
                        Task<Void, Never> {
                            await refreshDashboard()
                        }
                    }
                }
                .refreshable {
                    await refreshDashboard()
                }
                .sheet(isPresented: $isShowingTrainingInsights) {
                    TrainingInsightsView(
                        insightsStore: trainingInsightsStore,
                        insightsModel: trainingInsightsModel
                    )
                    .environmentObject(refreshCenter)
                }
                .background(FormaTokens.Color.canvas)
                .preferredColorScheme(.dark)
        }
    }

    private func refreshDashboard() async {
        await trainingInsightsStore.refresh()
        if trainingInsightsStore.integrationState.isConnected {
            appleHealthWorkoutCount = try? await TodayHealthWorkoutResolver.workoutCountToday(
                reader: trainingInsightsModel.workoutReaderForToday
            )
        } else {
            appleHealthWorkoutCount = nil
        }
        await model.refresh()
    }

    @ViewBuilder
    private var content: some View {
        switch model.viewState {
        case .loading:
            TodayLoadingView()
        case .empty:
            TodayEmptyStateView {
                Task { await refreshDashboard() }
            }
        case .error(let message):
            TodayErrorView(message: message) {
                Task { await refreshDashboard() }
            }
        case .loaded(let state):
            dashboard(state)
        }
    }

    private func dashboard(_ state: TodayDashboardState) -> some View {
        ScrollView {
            TodayReadOnlyView(
                state: state,
                trainingIntegration: trainingInsightsStore.integrationState,
                trainingDataSource: trainingInsightsStore.dataSource,
                appleHealthWorkoutCount: appleHealthWorkoutCount,
                onOpenCoach: { prefill in
                    onOpenCoach?(prefill)
                },
                onOpenTrainingInsights: {
                    isShowingTrainingInsights = true
                }
            )
            .padding(.horizontal, TodayLayout.horizontalPadding)
            .padding(.top, FormaTokens.Spacing.md)
            .padding(.bottom, TodayLayout.bottomScrollPadding)
        }
        .fitPilotScrollBottomInset()
    }
}

#Preview {
    let container = try! AppContainer(inMemory: true)
    TodayView(model: container.makeTodayModel())
        .environmentObject(container.refreshCenter)
        .environmentObject(container.trainingInsightsStore)
        .environmentObject(container.trainingInsightsModel)
}
