//
//  TrainingView.swift
//  Fitness Coach
//
//  FitPilot AI — Basic Training screen for workout logging.
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
                            model.showAddWorkout()
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("Add workout")
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
                .sheet(isPresented: $model.isShowingWorkoutEntrySheet) {
                    WorkoutEntrySheet(
                        errorMessage: model.formErrorMessage,
                        onSave: { formState in
                            await model.addWorkout(formState)
                        },
                        onCancel: {
                            model.dismissAddWorkout()
                        }
                    )
                }
                .sheet(item: $model.selectedWorkout) { workout in
                    WorkoutDetailView(
                        workout: workout,
                        onDelete: { id in
                            await model.deleteWorkout(id: id)
                        }
                    )
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.viewState {
        case .loading:
            TrainingLoadingView()
        case .empty:
            TrainingEmptyStateView {
                model.showAddWorkout()
            }
        case .error(let message):
            TrainingErrorView(message: message) {
                Task {
                    await model.refresh()
                }
            }
        case .loaded(let state):
            dashboard(state)
        }
    }

    private func dashboard(_ state: TrainingDashboardState) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                TrainingWorkoutSummaryCard(summary: state.summary)

                WorkoutListView(
                    title: "Today",
                    workouts: state.todaysWorkouts,
                    emptyMessage: "No workouts today.",
                    onSelect: { workout in
                        model.selectWorkout(workout)
                    },
                    onDelete: { id in
                        Task {
                            await model.deleteWorkout(id: id)
                        }
                    }
                )

                WorkoutListView(
                    title: "Recent Workouts",
                    workouts: state.recentWorkouts,
                    emptyMessage: "No recent workouts.",
                    onSelect: { workout in
                        model.selectWorkout(workout)
                    },
                    onDelete: { id in
                        Task {
                            await model.deleteWorkout(id: id)
                        }
                    }
                )
            }
            .padding()
        }
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
