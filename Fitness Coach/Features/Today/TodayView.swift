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
    @EnvironmentObject private var refreshCenter: AppRefreshCenter

    @State private var appleHealthWorkoutCount: Int?
    @State private var isShowingTrainingInsights = false

    /// Opens Coach with optional prefill when an action requires conversational AI.
    var onOpenCoach: ((String?) -> Void)?

    init(
        model: TodayModel,
        actionCoordinator: TodayActionCoordinator,
        onOpenCoach: ((String?) -> Void)? = nil
    ) {
        self.model = model
        _actionCoordinator = StateObject(wrappedValue: actionCoordinator)
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
                    await model.loadToday(activityContext: currentActivityContext)
                }
                .onChange(of: refreshCenter.refreshToken) { _, _ in
                    Task<Void, Never> {
                        await refreshDashboard()
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
                    await refreshDashboard()
                }
                .sheet(isPresented: $isShowingTrainingInsights) {
                    TrainingInsightsView(
                        insightsStore: trainingInsightsStore,
                        insightsModel: trainingInsightsModel
                    )
                    .environmentObject(refreshCenter)
                }
                .sheet(item: $actionCoordinator.logMealPresentation) { presentation in
                    TodayLogMealSheet(
                        initialMealType: presentation.mealType,
                        errorMessage: actionCoordinator.lastErrorMessage,
                        onSave: { actionCoordinator.saveMeal(from: $0) }
                    )
                }
                .sheet(isPresented: $actionCoordinator.isPresentingLogWeightSheet) {
                    TodayLogWeightSheet(
                        errorMessage: actionCoordinator.lastErrorMessage,
                        onSave: { actionCoordinator.saveWeight($0) }
                    )
                }
                .background(FormaTokens.Color.canvas)
                .preferredColorScheme(.dark)
        }
    }

    private func wireActionCoordinator() {
        actionCoordinator.onOpenCoach = { prefill in
            onOpenCoach?(prefill)
        }
        actionCoordinator.onOpenTrainingInsights = {
            isShowingTrainingInsights = true
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
        await model.refresh(activityContext: currentActivityContext)
    }

    private var currentActivityContext: TodayActivityContext {
        TodayActivityContext(
            trainingIntegration: trainingInsightsStore.integrationState,
            trainingDataSource: trainingInsightsStore.dataSource,
            appleHealthWorkoutCount: appleHealthWorkoutCount
        )
    }

    @ViewBuilder
    private var content: some View {
        switch model.viewState {
        case .loading:
            FormaScreenLoadingView(message: FormaProductCopy.Loading.today)
        case .empty:
            TodayEmptyStateView {
                Task { await refreshDashboard() }
            }
        case .error(let message):
            FormaScreenErrorView(message: message, onRetry: {
                Task { await refreshDashboard() }
            }, style: .tabRoot)
        case .loaded(let state):
            dashboard(state)
        }
    }

    private func dashboard(_ state: TodayDashboardState) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TodayLayout.sectionSpacing) {
                TodayReadOnlyView(
                    state: state,
                    actionCoordinator: actionCoordinator,
                    onOpenCoach: { prefill in
                        onOpenCoach?(prefill)
                    },
                    onLogMealFromPreview: {
                        actionCoordinator.handleCTA(
                            .logMeal(TodayCoachPrompt.logMeal()),
                            from: state.nextBestAction
                        )
                    }
                )
            }
            .padding(.horizontal, TodayLayout.horizontalPadding)
            .padding(.top, FormaTokens.Spacing.md)
            .padding(.bottom, TodayLayout.bottomScrollPadding)
        }
        .formaMainTabScrollInsets()
    }
}

#Preview {
    let container = try! AppContainer(inMemory: true)
    TodayView(
        model: container.makeTodayModel(),
        actionCoordinator: container.makeTodayActionCoordinator()
    )
    .environmentObject(container.refreshCenter)
    .environmentObject(container.trainingInsightsStore)
    .environmentObject(container.trainingInsightsModel)
}
