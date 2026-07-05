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
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.theme) private var theme
    @EnvironmentObject private var healthSyncStateStore: HealthSyncStateStore
    @Environment(\.appleHealthSettingsEnvironment) private var appleHealthSettingsEnvironment
    @Environment(\.accountDeletionCoordinator) private var accountDeletionCoordinator
    @Environment(\.settingsPrivacyDataEnvironment) private var settingsPrivacyDataEnvironment
    @EnvironmentObject private var consentStore: HealthSummarySyncConsentStore

    @State private var isShowingTrainingInsights = false
    @State private var weeklyRecommendationScrollTrigger = 0

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
        let _ = themeManager.themeRevision
        return NavigationStack {
            content
                .toolbar(.hidden, for: .navigationBar)
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
                    await performPullToRefresh()
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
                            weeklyReviewContext: model.editWeeklyReviewContext,
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
                        .formaThemeReactive()
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
                        .environment(\.accountDeletionCoordinator, accountDeletionCoordinator)
                        .environment(\.settingsPrivacyDataEnvironment, settingsPrivacyDataEnvironment)
                        .formaThemeReactive()
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
                .formaThemeReactive()
        }
    }

    private func performPullToRefresh() async {
        await model.performManualCrossDeviceRefresh()
        await trainingInsightsStore.refresh()
        await model.refresh()
    }

    /// Header Adjust pill — same wizard as the legacy top-right Adjust Plan control.
    private func openAdjustPlanFromHeader(healthConnected: Bool) {
        model.logPlanAdjustCTATapped(healthConnected: healthConnected)
        model.showEditPlan(entryPoint: .planTab)
    }

    /// Bottom dashboard Adjust Plan CTA — preserves the dedicated bottom entry analytics.
    private func openAdjustPlanFromBottomCTA(healthConnected: Bool) {
        model.logPlanAdjustCTATapped(healthConnected: healthConnected)
        model.showEditPlan(entryPoint: .adjustPlanCTA)
    }

    @ViewBuilder
    private var content: some View {
        switch model.viewState {
        case .loading:
            MainTabPageScaffold(
                title: FormaProductCopy.PlanHeader.title,
                subtitle: FormaProductCopy.PlanHeader.subtitle,
                scrollMode: .embedded
            ) {
                FormaScreenLoadingView(message: FormaProductCopy.Loading.plan)
            }
        case .empty:
            MainTabPageScaffold(
                title: FormaProductCopy.PlanHeader.title,
                subtitle: FormaProductCopy.PlanHeader.subtitle,
                scrollMode: .embedded
            ) {
                PlanEmptyStateView {
                    Task {
                        await model.createDefaultProfile()
                    }
                }
            }
        case .error(let message):
            MainTabPageScaffold(
                title: FormaProductCopy.PlanHeader.title,
                subtitle: FormaProductCopy.PlanHeader.subtitle,
                scrollMode: .embedded
            ) {
                FormaScreenErrorView(message: message, onRetry: {
                    Task {
                        await model.refresh()
                    }
                }, style: .detailScreen)
            }
        case .loaded(let state):
            strategyContent(state)
        }
    }

    @ViewBuilder
    private func strategyContent(_ state: PlanDashboardState) -> some View {
        let healthConnected = trainingInsightsStore.integrationState.isConnected
        let healthIntelligenceUIEnabled = HealthIntelligenceFeatureFlags.isUIEnabled

        MainTabPageScaffold(
            title: FormaProductCopy.PlanHeader.title,
            subtitle: FormaProductCopy.PlanHeader.subtitle,
            sectionSpacing: PlanLayout.sectionSpacing,
            showsCrossDeviceRefreshBanner: model.isCrossDeviceRefreshing,
            scrollTarget: MainTabScrollTarget(
                id: PlanDashboardContent.weeklyRecommendationScrollID,
                anchor: .center,
                trigger: weeklyRecommendationScrollTrigger
            ),
            trailingAction: {
                PageActionPill(
                    title: FormaProductCopy.PlanMissionControl.adjustPlanPill,
                    accessibilityHint: FormaProductCopy.PlanMissionControl.adjustPlanAccessibilityHint
                ) {
                    openAdjustPlanFromHeader(healthConnected: healthConnected)
                }
            }
        ) {
            PlanDashboardContent(
                state: state,
                healthIntelligenceUIEnabled: healthIntelligenceUIEnabled,
                planHealthIntelligenceSectionState: healthIntelligenceUIEnabled
                    ? model.planHealthIntelligenceSectionState
                    : nil,
                highlightWeeklyRecommendation: model.shouldHighlightWeeklyRecommendation,
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
                    openAdjustPlanFromBottomCTA(healthConnected: healthConnected)
                },
                onOpenSettings: {
                    model.showSettings()
                },
                onReviewWeeklyRecommendation: {
                    model.logWeeklyRecommendationTapped(healthConnected: healthConnected)
                    model.showEditPlanFromWeeklyReview(entryPoint: .weeklyReview)
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
        .onChange(of: model.shouldHighlightWeeklyRecommendation) { _, shouldHighlight in
            guard shouldHighlight else { return }
            weeklyRecommendationScrollTrigger += 1
            model.clearWeeklyRecommendationHighlight()
        }
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
        case .weeklyRecommendation:
            model.logWeeklyRecommendationShown(healthConnected: healthConnected)
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
    PlanPreviewScreens.screen(.aggressiveCut)
}
