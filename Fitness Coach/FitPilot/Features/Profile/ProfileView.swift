//
//  ProfileView.swift
//  Fitness Coach
//
//  FitPilot AI — Profile and settings screen.
//

import SwiftUI

struct ProfileView: View {
    @ObservedObject var model: ProfileModel
    @EnvironmentObject private var refreshCenter: AppRefreshCenter

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Profile")
                .toolbar {
                    if case .loaded = model.viewState {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Edit") {
                                model.showEditProfile()
                            }
                        }
                    }
                }
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
                        ProfileEditSheet(
                            formState: Binding(
                                get: { model.editFormState ?? formState },
                                set: { model.editFormState = $0 }
                            ),
                            errorMessage: model.formErrorMessage,
                            onSave: { state in
                                await model.saveProfile(state)
                            },
                            onCancel: {
                                model.dismissEditProfile()
                            },
                            onRegenerate: { state in
                                await model.previewRegeneratedTargets(from: state)
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
            VStack(alignment: .leading, spacing: 20) {
                ProfileSummaryCard(summary: state.profileSummary)

                readOnlySection(title: "Targets") {
                    readOnlyRow("Calories", state.targetSummary.calorieTargetText)
                    readOnlyRow("Protein", state.targetSummary.proteinTargetText)
                    readOnlyRow("Carbs", state.targetSummary.carbTargetText)
                    readOnlyRow("Fat", state.targetSummary.fatTargetText)
                    readOnlyRow("Water", state.targetSummary.waterTargetText)
                    readOnlyRow("Aggressiveness", state.targetSummary.aggressivenessText)
                    if let weeklyLoss = state.targetSummary.expectedWeeklyLossText {
                        readOnlyRow("Expected weekly loss", weeklyLoss)
                    }
                }

                readOnlySection(title: "Activity") {
                    readOnlyRow("Activity level", state.activitySummary.activityLevelText)
                    readOnlyRow("Training frequency", state.activitySummary.trainingFrequencyText)
                    readOnlyRow("Average steps", state.activitySummary.averageStepsText)
                }

                readOnlySection(title: "Preferences") {
                    readOnlyRow("Diet preference", state.preferenceSummary.dietPreferenceText)
                    readOnlyRow("Unit system", state.preferenceSummary.unitSystemText)
                }
            }
            .padding()
        }
    }

    private func readOnlySection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            VStack(spacing: 10) {
                content()
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    private func readOnlyRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.trailing)
        }
    }
}

#Preview {
    let container = try! AppContainer(inMemory: true)
    ProfileView(model: container.makeProfileModel())
        .environmentObject(container.refreshCenter)
}
