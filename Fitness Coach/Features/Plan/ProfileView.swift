//
//  ProfileView.swift
//  Fitness Coach
//
//  FitPilot AI — Plan: what strategy am I following?
//

import SwiftUI

struct ProfileView: View {
    @ObservedObject var model: ProfileModel
    @EnvironmentObject private var refreshCenter: AppRefreshCenter
    @EnvironmentObject private var trainingInsightsStore: TrainingInsightsStore
    @EnvironmentObject private var trainingInsightsModel: TrainingInsightsModel

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
                    if let formState = model.editFormState {
                        PlanEditWizard(
                            formState: Binding(
                                get: { model.editFormState ?? formState },
                                set: { model.editFormState = $0 }
                            ),
                            errorMessage: model.formErrorMessage,
                            onSave: { state in
                                await model.savePlanFromWizard(state)
                            },
                            onCancel: {
                                model.dismissEditPlan()
                            },
                            onRegenerate: { state in
                                await model.previewRegeneratedTargets(from: state)
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
                .preferredColorScheme(.dark)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.viewState {
        case .loading:
            ProfileLoadingView()
        case .empty:
            ProfileEmptyStateView {
                Task {
                    await model.createDefaultProfile()
                }
            }
        case .error(let message):
            ProfileErrorView(message: message) {
                Task {
                    await model.refresh()
                }
            }
        case .loaded(let state):
            dashboard(state)
        }
    }

    private func dashboard(_ state: ProfileDashboardState) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PlanLayout.sectionSpacing) {
                PlanStrategyHeroSection(state: state.strategy) {
                    model.showEditPlan()
                }

                PlanTodaysTargetsSection(targets: state.todaysTargets)

                PlanTrainingIntegrationSection(
                    integrationState: trainingInsightsStore.integrationState,
                    dataSource: trainingInsightsStore.dataSource,
                    onTap: {
                        isShowingTrainingInsights = true
                    }
                )

                PlanRationaleSection(rationale: state.rationale)

                PlanAboutYouSection(aboutYou: state.aboutYou)

                WhatHappensNextSection(state: state.whatHappensNext)
            }
            .padding(.horizontal, PlanLayout.horizontalPadding)
            .padding(.top, FormaTokens.Spacing.xs)
            .padding(.bottom, FormaMainTabLayout.scrollContentBottomPadding)
        }
        .formaMainTabScrollInsets()
    }
}

#Preview {
    let container = try! AppContainer(inMemory: true)
    ProfileView(model: container.makeProfileModel())
        .environmentObject(container.refreshCenter)
        .environmentObject(container.authManager)
        .environmentObject(container.trainingInsightsStore)
        .environmentObject(container.trainingInsightsModel)
}

#Preview("Loaded Plan") {
    ScrollView {
        VStack(alignment: .leading, spacing: PlanLayout.sectionSpacing) {
            PlanStrategyHeroSection(state: ProfilePreviewData.state.strategy, onEditPlan: {})
            PlanTodaysTargetsSection(targets: ProfilePreviewData.state.todaysTargets)
            PlanRationaleSection(rationale: ProfilePreviewData.state.rationale)
            PlanAboutYouSection(aboutYou: ProfilePreviewData.state.aboutYou)
            WhatHappensNextSection(state: ProfilePreviewData.state.whatHappensNext)
        }
        .padding(.horizontal, PlanLayout.horizontalPadding)
        .padding(.vertical, 24)
    }
}
