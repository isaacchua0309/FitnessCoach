//
//  TrainingView.swift
//  Fitness Coach
//
//  FitPilot AI — Read-only Training intelligence dashboard.
//
//  Answers: "How is my training going?" Workout logging lives in Coach only.
//

import SwiftUI

struct TrainingView: View {
    @ObservedObject var model: TrainingModel
    @EnvironmentObject private var refreshCenter: AppRefreshCenter

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Training")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            Task { await model.refresh() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .foregroundStyle(FormaTokens.Color.textSecondary)
                        }
                        .accessibilityLabel("Refresh training")
                    }
                }
                .task {
                    await model.loadTraining()
                }
                .onChange(of: refreshCenter.refreshToken) { _, _ in
                    Task { await model.refresh() }
                }
                .onAppear {
                    if case .loaded = model.viewState {
                        Task { await model.refresh() }
                    }
                }
                .sheet(item: $model.selectedWorkout) { workout in
                    WorkoutDetailView(workout: workout)
                }
                .background(FormaTokens.Color.canvas)
                .preferredColorScheme(.dark)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.viewState {
        case .loading:
            TrainingLoadingView()
        case .error(let message):
            TrainingErrorView(message: message) {
                Task { await model.refresh() }
            }
        case .loaded(let state):
            dashboard(state)
        }
    }

    private func dashboard(_ state: TrainingDashboardState) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TrainingLayout.sectionSpacing) {
                TrainingHeroSection(hero: state.hero)
                TrainingWeeklySummarySection(weekly: state.weekly)
                TrainingMuscleDistributionSection(items: state.muscleDistribution)
                TrainingRecentWorkoutsSection(workouts: state.recentWorkouts) { workout in
                    model.selectWorkout(workout)
                }
            }
            .padding(.horizontal, TrainingLayout.horizontalPadding)
            .padding(.top, FormaTokens.Spacing.md)
            .padding(.bottom, FormaTokens.Spacing.sm)
        }
        .fitPilotScrollBottomInset()
        .refreshable {
            await model.refresh()
        }
    }
}

#Preview {
    let container = try! AppContainer(inMemory: true)
    TrainingView(model: container.makeTrainingModel())
        .environmentObject(container.refreshCenter)
}
