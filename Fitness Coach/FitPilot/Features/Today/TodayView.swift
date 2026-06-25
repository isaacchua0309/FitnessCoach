//
//  TodayView.swift
//  Fitness Coach
//
//  FitPilot AI — Main Today dashboard screen.
//

import SwiftUI

struct TodayView: View {

    @StateObject private var model: TodayModel
    @State private var isShowingWeightPrompt = false
    @State private var weightInput = ""

    init(model: TodayModel) {
        _model = StateObject(wrappedValue: model)
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Today")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            Task { await model.refresh() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
                .task {
                    await model.loadToday()
                }
                .refreshable {
                    await model.refresh()
                }
                .alert("Log Weight", isPresented: $isShowingWeightPrompt) {
                    TextField("Weight in kg", text: $weightInput)
                        .keyboardType(.decimalPad)
                    Button("Cancel", role: .cancel) {
                        weightInput = ""
                    }
                    Button("Save") {
                        let value = Double(weightInput)
                        weightInput = ""
                        if let value {
                            Task { await model.logWeight(value) }
                        }
                    }
                } message: {
                    Text("Enter today's morning weight.")
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.viewState {
        case .loading:
            TodayLoadingView()
        case .empty:
            TodayEmptyStateView {
                Task { await model.refresh() }
            }
        case .error(let message):
            TodayErrorView(message: message) {
                Task { await model.refresh() }
            }
        case .loaded(let state):
            dashboard(state)
        }
    }

    private func dashboard(_ state: TodayDashboardState) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header(for: state.date)

                if let coachingNote = state.coachingNote {
                    Label(coachingNote, systemImage: "lightbulb")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                }

                MacroSummaryCard(summary: state.macroSummary, calories: state.calorieSummary)
                WaterSummaryCard(summary: state.waterSummary) {
                    Task { await model.addWater(amountMl: 500) }
                }
                WeightSummaryCard(summary: state.weightSummary) {
                    isShowingWeightPrompt = true
                }
                WorkoutSummaryCard(summary: state.workoutSummary)
                FoodTimelineView(entries: state.foodEntries)
                TodayQuickActionsView(
                    onStartNewDay: { Task { await model.startNewDay() } },
                    onAddWater: { Task { await model.addWater(amountMl: 500) } },
                    onLogWeight: { isShowingWeightPrompt = true },
                    onRefresh: { Task { await model.refresh() } }
                )
            }
            .padding()
        }
    }

    private func header(for date: Date) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Daily Dashboard")
                .font(.title2.bold())
            Text(date.formatted(date: .complete, time: .omitted))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    TodayView(model: try! AppContainer(inMemory: true).makeTodayModel())
}
