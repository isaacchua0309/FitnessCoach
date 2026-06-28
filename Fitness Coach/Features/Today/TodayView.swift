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
    @State private var appleHealthWeeklyWorkoutCount: Int?
    @State private var appleHealthStepsToday: Int?
    @State private var isShowingTrainingInsights = false

    /// Opens Coach with optional prefill when an action requires conversational AI.
    var onOpenCoach: ((String?) -> Void)?
    var onOpenJourney: (() -> Void)?
    var onOpenPlan: (() -> Void)?

    init(
        model: TodayModel,
        actionCoordinator: TodayActionCoordinator,
        onOpenCoach: ((String?) -> Void)? = nil,
        onOpenJourney: (() -> Void)? = nil,
        onOpenPlan: (() -> Void)? = nil
    ) {
        self.model = model
        _actionCoordinator = StateObject(wrappedValue: actionCoordinator)
        self.onOpenCoach = onOpenCoach
        self.onOpenJourney = onOpenJourney
        self.onOpenPlan = onOpenPlan
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
                .sheet(isPresented: $actionCoordinator.isPresentingAddWaterSheet) {
                    TodayAddWaterSheet(
                        presetAmountsMl: TodayActionCoordinator.defaultWaterPresetAmountsMl,
                        errorMessage: actionCoordinator.lastErrorMessage,
                        onAdd: { actionCoordinator.addWater(amountMl: $0) }
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
                .background(FormaTokens.Color.canvas)
                .preferredColorScheme(.dark)
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
            let workoutReader = trainingInsightsModel.workoutReaderForToday
            appleHealthWorkoutCount = try? await TodayHealthWorkoutResolver.workoutCountToday(
                reader: workoutReader
            )
            appleHealthWeeklyWorkoutCount = try? await TodayHealthWorkoutResolver.workoutCountThisWeek(
                reader: workoutReader
            )
            appleHealthStepsToday = try? await TodayHealthStepResolver.stepsToday(
                reader: trainingInsightsModel.stepReaderForToday
            )
        } else {
            appleHealthWorkoutCount = nil
            appleHealthWeeklyWorkoutCount = nil
            appleHealthStepsToday = nil
        }
        await model.refresh(activityContext: currentActivityContext)
    }

    private var currentActivityContext: TodayActivityContext {
        TodayActivityContext(
            trainingIntegration: trainingInsightsStore.integrationState,
            trainingDataSource: trainingInsightsStore.dataSource,
            appleHealthWorkoutCount: appleHealthWorkoutCount,
            stepsToday: appleHealthStepsToday,
            weeklyWorkoutCount: appleHealthWeeklyWorkoutCount
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
                    onOpenJourney: {
                        onOpenJourney?()
                    },
                    onOpenPlan: {
                        onOpenPlan?()
                    }
                )
            }
            .padding(.horizontal, TodayLayout.horizontalPadding)
            .padding(.top, FormaTokens.Spacing.md)
            .padding(.bottom, TodayLayout.bottomScrollPadding + TodayLayout.quickActionFABClearance)
        }
        .formaMainTabScrollInsets()
        .overlay(alignment: .bottomTrailing) {
            TodayQuickActionButton(
                menuItems: TodayQuickActionPolicy.menuItems(),
                onSelect: { kind in
                    actionCoordinator.performQuickAction(kind)
                }
            )
            .padding(.trailing, TodayLayout.horizontalPadding)
            .padding(.bottom, TodayLayout.quickActionFABBottomPadding)
        }
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
