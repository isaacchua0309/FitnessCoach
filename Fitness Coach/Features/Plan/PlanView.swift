//
//  PlanView.swift
//  Fitness Coach
//
//  FitPilot AI — Plan Mission Control dashboard.
//

import SwiftUI

struct PlanView: View {
    @ObservedObject var model: PlanModel
    var onGoToToday: (() -> Void)? = nil
    var onGoToJourney: (() -> Void)? = nil
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
            dashboard(state)
        }
    }

    @ViewBuilder
    private func dashboard(_ state: PlanDashboardState) -> some View {
        let healthConnected = trainingInsightsStore.integrationState.isConnected

        ScrollView {
            VStack(alignment: .leading, spacing: PlanLayout.sectionSpacing) {
                // 1. Mission Control / Goal Progress
                PlanMissionControlHeroSection(state: state.missionControl.mission)
                    .onAppear {
                        model.logSectionImpression(.goalCard, healthConnected: healthConnected)
                    }

                // 2. Today's Mission
                PlanTodayMissionSection(
                    state: state.missionControl.todayMission,
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

                // 3. This Week
                PlanThisWeekSection(state: state.missionControl.week)
                    .onAppear {
                        model.logSectionImpression(.weekSection, healthConnected: healthConnected)
                    }

                // 4. Next Milestone
                PlanNextMilestoneSection(
                    state: state.missionControl.nextMilestone,
                    onGoToJourney: onGoToJourney.map { handler in
                        {
                            model.logPlanJourneyTapped(healthConnected: healthConnected)
                            handler()
                        }
                    }
                )

                // 5. Why This Works
                PlanRationaleSection(
                    rationale: state.rationale,
                    onCalculationDetailsOpened: {
                        model.logPlanCalculationDetailsOpened(healthConnected: healthConnected)
                    }
                )
                .onAppear {
                    model.logSectionImpression(.rationale, healthConnected: healthConnected)
                }

                // 6. Activity Assumptions
                PlanActivityAssumptionsSection(
                    state: state.missionControl.activityAssumptions,
                    onAdjustActivity: {
                        model.showEditPlanActivity()
                    }
                )
                .onAppear {
                    model.logSectionImpression(.activityAssumptions, healthConnected: healthConnected)
                }

                // 7. Plan Confidence
                PlanConfidenceSection(state: state.missionControl.confidence)

                // 8. Apple Health
                PlanTrainingIntegrationSection(
                    integrationState: trainingInsightsStore.integrationState,
                    dataSource: trainingInsightsStore.dataSource,
                    onTap: {
                        model.logPlanHealthConnectTapped(
                            entryPoint: .trainingIntegrationCard,
                            healthConnected: healthConnected
                        )
                        isShowingTrainingInsights = true
                    }
                )

                // 9. Adjust Plan
                PlanAdjustmentSection(state: state.missionControl.adjustment) {
                    model.showEditPlan()
                }
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
            PlanMissionControlHeroSection(
                state: PlanPreviewData.state.missionControl.mission
            )
            PlanTodayMissionSection(
                state: PlanPreviewData.state.missionControl.todayMission,
                onGoToToday: {}
            )
            PlanThisWeekSection(state: PlanPreviewData.state.missionControl.week)
            PlanNextMilestoneSection(
                state: PlanPreviewData.state.missionControl.nextMilestone,
                onGoToJourney: {}
            )
            PlanRationaleSection(rationale: PlanPreviewData.state.rationale)
            PlanActivityAssumptionsSection(
                state: PlanPreviewData.state.missionControl.activityAssumptions,
                onAdjustActivity: {}
            )
            PlanConfidenceSection(state: PlanPreviewData.state.missionControl.confidence)
            PlanTrainingIntegrationSection(
                integrationState: .notConnected,
                dataSource: .appleHealth,
                onTap: {}
            )
            PlanAdjustmentSection(
                state: PlanPreviewData.state.missionControl.adjustment,
                onAdjustPlan: {}
            )
        }
        .padding(.horizontal, PlanLayout.horizontalPadding)
        .padding(.vertical, 24)
    }
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
