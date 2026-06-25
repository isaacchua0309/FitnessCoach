//
//  ProgressView.swift
//  Fitness Coach
//
//  FitPilot AI — Read-only progress trends screen.
//
//  Views render state only. They do not call services directly, access
//  SwiftData, call AI, or calculate metrics.
//

import SwiftUI

struct ProgressView: View {

    @ObservedObject var model: ProgressModel
    @EnvironmentObject private var refreshCenter: AppRefreshCenter

    init(model: ProgressModel) {
        self.model = model
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Progress")
                .task {
                    await model.loadProgress()
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
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.viewState {
        case .loading:
            ProgressLoadingView()
        case .empty:
            ProgressEmptyStateView {
                Task { await model.refresh() }
            }
        case .error(let message):
            ProgressErrorView(message: message) {
                Task { await model.refresh() }
            }
        case .loaded(let state):
            dashboard(state)
        }
    }

    private func dashboard(_ state: ProgressDashboardState) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Selected range")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ProgressRangeSelector(selectedRangeDays: state.selectedRangeDays) { days in
                        Task { await model.selectRange(days: days) }
                    }
                }

                WeightTrendSummaryCard(summary: state.weightSummary)
                WeightTrendChart(points: state.weightChartPoints)
                NutritionTrendSummaryCard(summary: state.nutritionSummary)
                WaterTrendSummaryCard(summary: state.waterSummary)
                MaintenanceEstimateCard(estimate: state.maintenanceEstimate)
                GoalProjectionCard(projection: state.goalProjection)

                if let workoutSummary = state.workoutSummary {
                    workoutSummaryCard(workoutSummary)
                }
            }
            .padding()
        }
    }

    private func workoutSummaryCard(_ summary: ProgressWorkoutSummary) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Workouts", systemImage: "figure.strengthtraining.traditional")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                ProgressMetricCard(
                    title: "Workout count",
                    value: "\(summary.workoutCount)",
                    systemImage: "checklist"
                )
                ProgressMetricCard(
                    title: "Calories burned",
                    value: ProgressFormatter.kcal(summary.totalEstimatedCaloriesBurned),
                    systemImage: "flame"
                )
                ProgressMetricCard(
                    title: "Per week",
                    value: String(format: "%.1f", summary.averageWorkoutsPerWeek),
                    systemImage: "calendar"
                )
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
    }
}

#Preview {
    let container = try! AppContainer(inMemory: true)
    ProgressView(model: container.makeProgressModel())
        .environmentObject(container.refreshCenter)
}
