//
//  PlanView.swift
//  Fitness Coach
//
//  FitPilot AI — Plan strategy screen.
//

import SwiftUI

struct PlanView: View {
    @ObservedObject var model: PlanModel
    var healthIntelligenceAnalyticsCoordinator: HealthIntelligenceAnalyticsCoordinator?
    var onGoToToday: (() -> Void)? = nil
    @EnvironmentObject private var refreshCenter: AppRefreshCenter
    @EnvironmentObject private var trainingInsightsStore: TrainingInsightsStore
    @EnvironmentObject private var trainingInsightsModel: TrainingInsightsModel
    @EnvironmentObject private var themeStore: ThemeStore
    @EnvironmentObject private var healthSyncStateStore: HealthSyncStateStore
    @Environment(\.appleHealthSettingsEnvironment) private var appleHealthSettingsEnvironment
    @EnvironmentObject private var consentStore: HealthSummarySyncConsentStore

    @State private var isShowingTrainingInsights = false

    private var settingsBodyDetailsInput: BodyDetailsSettingsPresentationInput? {
        guard let formState = model.editFormState else { return nil }
        if case .loaded(let state) = model.viewState {
            return BodyDetailsSettingsPresentationInput(
                formState: formState,
                currentWeightKg: state.profile.currentWeightKg
            )
        }
        return BodyDetailsSettingsPresentationInput(formState: formState)
    }

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
                                        .foregroundStyle(FormaPlanTokens.Color.planAccent)
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
                                try await model.savePlanFromWizard(state)
                            },
                            onCancel: {
                                model.dismissEditPlan()
                            },
                            onPrepareTargets: { state in
                                try await model.prepareTargetPreview(from: state)
                            }
                        )
                        .tint(FormaPlanTokens.Color.planAccent)
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
                            },
                            bodyDetailsInput: settingsBodyDetailsInput,
                            onUpdateInPlan: {
                                BodyDetailsSettingsActionHandler.openUpdateInPlan(
                                    dismissSettings: { model.dismissSettings() },
                                    showAdjustPlan: {
                                        model.showEditPlan(
                                            initialStep: .heightAndWeight,
                                            entryPoint: PlanAdjustPlanEntryPoint.settingsBodyDetails
                                        )
                                    }
                                )
                            }
                        )
                        .environmentObject(trainingInsightsStore)
                        .environmentObject(healthSyncStateStore)
                        .environmentObject(consentStore)
                        .environmentObject(themeStore)
                        .environment(\.appleHealthSettingsEnvironment, appleHealthSettingsEnvironment)
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
        let healthIntelligenceUIEnabled = HealthIntelligenceFeatureFlags.isUIEnabled

        ScrollView {
            PlanDashboardContent(
                state: state,
                healthIntelligenceUIEnabled: healthIntelligenceUIEnabled,
                planHealthIntelligenceSectionState: healthIntelligenceUIEnabled
                    ? model.planHealthIntelligenceSectionState
                    : nil,
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
                    model.logPlanAdjustCTATapped(healthConnected: healthConnected)
                    model.showEditPlan()
                },
                onCalculationDetailsOpened: {
                    model.logPlanCalculationTapped(healthConnected: healthConnected)
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
                onConnectHealth: healthIntelligenceUIEnabled
                    ? {
                        model.logPlanHealthConnectTapped(
                            entryPoint: .planConfidence,
                            healthConnected: healthConnected
                        )
                        healthIntelligenceAnalyticsCoordinator?.logHealthPermissionCTATapped(surface: .plan)
                        isShowingTrainingInsights = true
                    }
                    : nil,
                onPlanHealthMissingDataAction: healthIntelligenceUIEnabled
                    ? { action in
                        handlePlanHealthMissingDataAction(
                            action,
                            healthConnected: healthConnected
                        )
                    }
                    : nil,
                healthIntelligenceAnalyticsCoordinator: healthIntelligenceAnalyticsCoordinator,
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

    private func handlePlanHealthMissingDataAction(
        _ action: PlanHealthMissingDataActionState,
        healthConnected: Bool
    ) {
        switch action.id {
        case "connect-health", "partial-permissions":
            model.logPlanHealthConnectTapped(
                entryPoint: .planConfidence,
                healthConnected: healthConnected
            )
            healthIntelligenceAnalyticsCoordinator?.logHealthPermissionCTATapped(surface: .plan)
            isShowingTrainingInsights = true
        default:
            break
        }
    }

    private func logSectionImpression(
        _ section: PlanProductSection,
        healthConnected: Bool
    ) {
        switch section {
        case .goalProgress:
            model.logSectionImpression(.strategy, healthConnected: healthConnected)
        case .planStatus:
            model.logSectionImpression(.status, healthConnected: healthConnected)
        case .planConfidence:
            model.logSectionImpression(.confidence, healthConnected: healthConnected)
        case .header, .todayMission, .whyThisWorks, .whenToAdjust, .planAssumptions, .nextReview, .adjustPlanCTA:
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
