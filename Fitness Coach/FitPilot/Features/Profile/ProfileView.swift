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

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Plan")
                .task {
                    await model.loadProfile()
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
                        ProfileSettingsSheet(
                            formState: Binding(
                                get: { model.editFormState ?? formState },
                                set: { model.editFormState = $0 }
                            ),
                            errorMessage: model.formErrorMessage,
                            onSave: { state in
                                await model.saveSettings(state)
                            },
                            onCancel: {
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

                PlanRationaleSection(rationale: state.rationale)

                PlanAdaptiveCoachSection(state: state.adaptiveCoach)

                PlanLifestyleSection(lifestyle: state.lifestyle)

                PlanTimelineSection(timeline: state.timeline)

                PlanAboutYouSection(aboutYou: state.aboutYou)

                PlanSettingsSection {
                    model.showSettings()
                }
            }
            .padding(.horizontal, PlanLayout.horizontalPadding)
            .padding(.vertical, 24)
        }
    }
}

#Preview {
    let container = try! AppContainer(inMemory: true)
    ProfileView(model: container.makeProfileModel())
        .environmentObject(container.refreshCenter)
}

#Preview("Loaded Plan") {
    ScrollView {
        VStack(alignment: .leading, spacing: PlanLayout.sectionSpacing) {
            PlanStrategyHeroSection(state: ProfilePreviewData.state.strategy, onEditPlan: {})
            PlanTodaysTargetsSection(targets: ProfilePreviewData.state.todaysTargets)
            PlanRationaleSection(rationale: ProfilePreviewData.state.rationale)
            PlanAdaptiveCoachSection(state: ProfilePreviewData.state.adaptiveCoach)
        }
        .padding(.horizontal, PlanLayout.horizontalPadding)
        .padding(.vertical, 24)
    }
}
