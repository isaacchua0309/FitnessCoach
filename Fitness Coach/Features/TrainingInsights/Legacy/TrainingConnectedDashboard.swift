//
//  TrainingConnectedDashboard.swift
//  Fitness Coach
//
//  Forma — Legacy training dashboard shown when Apple Health is connected.
//
//  Stage 3 still reads local SwiftData until HealthKit sync ships.
//

import SwiftUI

struct TrainingConnectedDashboard: View {
    @ObservedObject var model: TrainingModel
    @EnvironmentObject private var refreshCenter: AppRefreshCenter

    var body: some View {
        content
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
    TrainingConnectedDashboard(model: container.makeTrainingModel())
        .environmentObject(container.refreshCenter)
        .background(FormaTokens.Color.canvas)
        .preferredColorScheme(.dark)
}
