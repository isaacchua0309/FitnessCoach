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
                .navigationTitle(FormaProductCopy.PlanHeader.title)
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
            PlanDashboardContent(
                state: state,
                onGoToToday: onGoToToday.map { handler in
                    {
                        model.logPlanTodayTapped(healthConnected: healthConnected)
                        handler()
                    }
                },
                onAdjustActivity: {
                    model.showEditPlanActivity()
                },
                onAdjustPlan: {
                    model.showEditPlan()
                },
                onCalculationDetailsOpened: {
                    model.logPlanCalculationDetailsOpened(healthConnected: healthConnected)
                },
                onAppleHealthTap: state.confidence.showsAppleHealthAction
                    ? {
                        model.logPlanHealthConnectTapped(
                            entryPoint: .planConfidence,
                            healthConnected: healthConnected
                        )
                        isShowingTrainingInsights = true
                    }
                    : nil,
                onSectionAppear: { section in
                    logSectionImpression(section, healthConnected: healthConnected)
                }
            )
        }
        .formaMainTabScrollInsets()
        .onAppear {
            model.logPlanViewed(healthConnected: healthConnected)
        }
    }

    private func logSectionImpression(
        _ section: PlanProductSection,
        healthConnected: Bool
    ) {
        switch section {
        case .goalProgress:
            model.logSectionImpression(.goalCard, healthConnected: healthConnected)
        case .todayMission:
            model.logSectionImpression(.todayMission, healthConnected: healthConnected)
        case .whyThisWorks:
            model.logSectionImpression(.rationale, healthConnected: healthConnected)
        case .planAssumptions:
            model.logSectionImpression(.planAssumptions, healthConnected: healthConnected)
        case .header, .planStatus, .planConfidence, .whenToAdjust, .nextReview, .adjustPlanCTA:
            break
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
    NavigationStack {
        PlanPreviewScreens.content(.aggressiveCut)
            .navigationTitle(FormaProductCopy.PlanHeader.title)
    }
}
