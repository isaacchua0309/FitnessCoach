//
//  PlanView.swift
//  Fitness Coach
//
//  FitPilot AI — Plan strategy screen.
//

import SwiftUI

struct PlanView: View {
    @ObservedObject var model: PlanModel
    var onGoToToday: (() -> Void)? = nil
    @EnvironmentObject private var refreshCenter: AppRefreshCenter
    @EnvironmentObject private var trainingInsightsStore: TrainingInsightsStore
    @EnvironmentObject private var trainingInsightsModel: TrainingInsightsModel
    @EnvironmentObject private var themeStore: ThemeStore

    @State private var isShowingTrainingInsights = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Plan")
                .toolbar {
                    if case .loaded = model.viewState {
                        ToolbarItem(placement: .topBarTrailing) {
                            HStack(spacing: FormaTokens.Spacing.sm) {
                                Button {
                                    model.showEditPlan()
                                } label: {
                                    Text(FormaProductCopy.PlanMissionControl.adjustPlan)
                                        .font(FormaTokens.Typography.body.weight(.semibold))
                                        .foregroundStyle(FormaTokens.Theme.primary)
                                }
                                .accessibilityHint(FormaProductCopy.PlanMissionControl.adjustPlanAccessibilityHint)

                                Button {
                                    model.showSettings()
                                } label: {
                                    Image(systemName: "gearshape")
                                        .font(FormaTokens.Typography.body.weight(.medium))
                                        .foregroundStyle(FormaTokens.Color.textSecondary)
                                }
                                .accessibilityLabel("Settings")
                            }
                        }
                    }
                }
                .task {
                    await trainingInsightsStore.refresh()
                    await model.loadProfile()
                }
                .onChange(of: refreshCenter.refreshToken) { _, _ in
                    Task {
                        await trainingInsightsStore.refresh()
                        await model.refresh()
                    }
                }
                .onAppear {
                    if case .loaded = model.viewState {
                        Task {
                            await trainingInsightsStore.refresh()
                            await model.refresh()
                        }
                    }
                }
                .refreshable {
                    await trainingInsightsStore.refresh()
                    await model.refresh()
                }
                .sheet(isPresented: $isShowingTrainingInsights) {
                    TrainingInsightsView(
                        insightsStore: trainingInsightsStore,
                        insightsModel: trainingInsightsModel
                    )
                    .environmentObject(refreshCenter)
                }
                .sheet(isPresented: $model.isShowingEditSheet) {
                    if let formState = model.editFormState,
                       let baselineProfile = model.editBaselineProfile {
                        PlanEditWizard(
                            formState: Binding(
                                get: { model.editFormState ?? formState },
                                set: { model.editFormState = $0 }
                            ),
                            baselineProfile: baselineProfile,
                            initialStep: model.editPlanInitialStep,
                            errorMessage: model.formErrorMessage,
                            onSave: { state in
                                await model.savePlanFromWizard(state)
                            },
                            onCancel: {
                                model.dismissEditPlan()
                            },
                            onPrepareTargets: { state in
                                try await model.prepareTargetPreview(from: state)
                            }
                        )
                    }
                }
                .sheet(isPresented: $model.isShowingSettingsSheet) {
                    if let formState = model.editFormState {
                        SettingsRootView(
                            formState: Binding(
                                get: { model.editFormState ?? formState },
                                set: { model.editFormState = $0 }
                            ),
                            errorMessage: model.formErrorMessage,
                            onSaveUnits: { state in
                                await model.saveSettings(state)
                            },
                            onDismiss: {
                                model.dismissSettings()
                            }
                        )
                        .environmentObject(themeStore)
                    }
                }
                .sheet(isPresented: $model.isShowingTargetRegenerationSheet) {
                    if let preview = model.generatedTargetPreview {
                        TargetRegenerationSheet(
                            preview: preview,
                            onApply: {
                                await model.applyGeneratedTargets()
                            },
                            onCancel: {
                                model.dismissTargetRegeneration()
                            }
                        )
                    }
                }
                .background(FormaTokens.Color.canvas)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.viewState {
        case .loading:
            FormaScreenLoadingView(message: FormaProductCopy.Loading.plan)
        case .empty:
            PlanEmptyStateView {
                Task {
                    await model.createDefaultProfile()
                }
            }
        case .error(let message):
            FormaScreenErrorView(message: message, onRetry: {
                Task {
                    await model.refresh()
                }
            }, style: .detailScreen)
        case .loaded(let state):
            strategyContent(state)
        }
    }

    @ViewBuilder
    private func strategyContent(_ state: PlanDashboardState) -> some View {
        let healthConnected = trainingInsightsStore.integrationState.isConnected

        ScrollView {
            VStack(alignment: .leading, spacing: PlanLayout.sectionSpacing) {
                PlanMissionControlHeroSection(strategy: state.strategy)
                    .onAppear {
                        model.logSectionImpression(.goalCard, healthConnected: healthConnected)
                    }

                PlanDailyTargetsSection(
                    state: state.dailyTargets,
                    onGoToToday: onGoToToday.map { handler in
                        {
                            model.logPlanTodayTapped(healthConnected: healthConnected)
                            handler()
                        }
                    }
                )
                .onAppear {
                    model.logSectionImpression(.todayMission, healthConnected: healthConnected)
                }

                PlanRationaleSection(
                    explanation: state.explanation,
                    onCalculationDetailsOpened: {
                        model.logPlanCalculationDetailsOpened(healthConnected: healthConnected)
                    }
                )
                .onAppear {
                    model.logSectionImpression(.rationale, healthConnected: healthConnected)
                }

                PlanAssumptionsSection(
                    state: state.assumptions,
                    onAdjustActivity: {
                        model.showEditPlanActivity()
                    }
                )
                .onAppear {
                    model.logSectionImpression(.planAssumptions, healthConnected: healthConnected)
                }

                PlanConfidenceSection(
                    state: state.confidence,
                    onAppleHealthTap: state.confidence.showsAppleHealthAction
                        ? {
                            model.logPlanHealthConnectTapped(
                                entryPoint: .planConfidence,
                                healthConnected: healthConnected
                            )
                            isShowingTrainingInsights = true
                        }
                        : nil
                )
            }
            .padding(.horizontal, PlanLayout.horizontalPadding)
            .padding(.top, FormaTokens.Spacing.xs)
            .padding(.bottom, FormaMainTabLayout.scrollContentBottomPadding)
        }
        .formaMainTabScrollInsets()
        .onAppear {
            model.logPlanViewed(healthConnected: healthConnected)
        }
    }
}

#Preview {
    let container = try! AppContainer(inMemory: true)
    PlanView(model: container.makePlanModel())
        .environmentObject(container.refreshCenter)
        .environmentObject(container.authManager)
        .environmentObject(container.trainingInsightsStore)
        .environmentObject(container.trainingInsightsModel)
        .environmentObject(container.themeStore)
        .formaThemePreview()
}

#Preview("Loaded Plan") {
    ScrollView {
        VStack(alignment: .leading, spacing: PlanLayout.sectionSpacing) {
            PlanMissionControlHeroSection(strategy: PlanPreviewData.state.strategy)
            PlanDailyTargetsSection(
                state: PlanPreviewData.state.dailyTargets,
                onGoToToday: {}
            )
            PlanRationaleSection(explanation: PlanPreviewData.state.explanation)
            PlanAssumptionsSection(
                state: PlanPreviewData.state.assumptions,
                onAdjustActivity: {}
            )
            PlanConfidenceSection(state: PlanPreviewData.state.confidence)
        }
        .padding(.horizontal, PlanLayout.horizontalPadding)
        .padding(.vertical, 24)
    }
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
