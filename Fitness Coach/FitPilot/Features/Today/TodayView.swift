//
//  TodayView.swift
//  Fitness Coach
//
//  FitPilot AI — Main Today dashboard screen.
//

import SwiftUI

struct TodayView: View {

    @ObservedObject var model: TodayModel
    @EnvironmentObject private var refreshCenter: AppRefreshCenter
    @State private var isShowingWeightPrompt = false
    @State private var weightInput = ""
    @State private var foodEntryPendingDelete: FoodEntry?

    init(model: TodayModel) {
        self.model = model
    }

    private var foodEditorMode: FoodEntryEditorMode {
        if let entry = model.editingFoodEntry {
            return .edit(entry)
        }
        return .add
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
                .onChange(of: refreshCenter.refreshToken) { _, _ in
                    Task<Void, Never> {
                        await model.refresh()
                    }
                }
                .onAppear {
                    if case .loaded = model.viewState {
                        Task<Void, Never> {
                            await model.refresh()
                        }
                    }
                }
                .refreshable {
                    await model.refresh()
                }
                .sheet(isPresented: $model.isShowingFoodEntrySheet) {
                    foodEntrySheet
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
                .alert("Delete Food", isPresented: deleteConfirmationBinding) {
                    Button("Cancel", role: .cancel) {
                        foodEntryPendingDelete = nil
                    }
                    Button("Delete", role: .destructive) {
                        if let entry = foodEntryPendingDelete {
                            foodEntryPendingDelete = nil
                            Task { await model.deleteFoodEntry(entry) }
                        }
                    }
                } message: {
                    Text("This will remove the food from today's log.")
                }
        }
    }

    private var deleteConfirmationBinding: Binding<Bool> {
        Binding(
            get: { foodEntryPendingDelete != nil },
            set: { isPresented in
                if !isPresented {
                    foodEntryPendingDelete = nil
                }
            }
        )
    }

    @ViewBuilder
    private var foodEntrySheet: some View {
        ManualFoodEntrySheet(
            mode: foodEditorMode,
            errorMessage: model.foodEntryErrorMessage,
            onSave: { formState in
                await model.saveFoodEntry(formState)
            },
            onDelete: foodDeleteHandler,
            onCancel: {
                model.dismissFoodEditor()
            }
        )
    }

    private var foodDeleteHandler: (() async -> Void)? {
        guard let entry = model.editingFoodEntry else { return nil }
        return {
            await model.deleteFoodEntry(entry)
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
                TodayDailyReviewCard(
                    review: state.dailyReview,
                    isGenerating: model.isGeneratingDailyReview,
                    onGenerate: {
                        Task { await model.generateDailyReview() }
                    }
                )
                FoodTimelineView(
                    entries: state.foodEntries,
                    onSelectFood: { entry in
                        model.showEditFood(entry)
                    },
                    onDeleteFood: { entry in
                        foodEntryPendingDelete = entry
                    }
                )
                TodayQuickActionsView(
                    onAddFood: { model.showAddFood() },
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
    let container = try! AppContainer(inMemory: true)
    TodayView(model: container.makeTodayModel())
        .environmentObject(container.refreshCenter)
}
