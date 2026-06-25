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

    var onOpenTraining: (() -> Void)?

    @State private var isShowingWeightPrompt = false
    @State private var weightInput = ""
    @State private var isShowingWaterPrompt = false
    @State private var waterInput = ""
    @State private var foodEntryPendingDelete: FoodEntry?
    @State private var isFoodTimelineExpanded = false
    @State private var isDailyReviewExpanded = false

    init(model: TodayModel, onOpenTraining: (() -> Void)? = nil) {
        self.model = model
        self.onOpenTraining = onOpenTraining
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
                        Menu {
                            Button {
                                Task { await model.startNewDay() }
                            } label: {
                                Label("Start New Day", systemImage: "calendar.badge.plus")
                            }
                            Button {
                                Task { await model.refresh() }
                            } label: {
                                Label("Refresh", systemImage: "arrow.clockwise")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
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
                .alert("Log Water", isPresented: $isShowingWaterPrompt) {
                    TextField("Amount in ml", text: $waterInput)
                        .keyboardType(.numberPad)
                    Button("Cancel", role: .cancel) {
                        waterInput = ""
                    }
                    Button("Save") {
                        let value = Int(waterInput)
                        waterInput = ""
                        if let value {
                            Task { await model.addWater(amountMl: value) }
                        }
                    }
                } message: {
                    Text("Enter how much water you drank.")
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
            VStack(alignment: .leading, spacing: 12) {
                Text(state.date.formatted(date: .complete, time: .omitted))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TodaySummaryCard(
                    calories: state.calorieSummary,
                    macros: state.macroSummary,
                    water: state.waterSummary,
                    coachingNote: state.coachingNote
                )

                TodayQuickActionBar(
                    onAddFood: { model.showAddFood() },
                    onAddWater: { Task { await model.addWater(amountMl: 500) } },
                    onLogWeight: { isShowingWeightPrompt = true },
                    onOpenTraining: { onOpenTraining?() }
                )

                HStack(spacing: 8) {
                    CompactWaterCard(
                        summary: state.waterSummary,
                        canUndoWater: state.waterSummary.consumedMl > 0,
                        onAddWater: { Task { await model.addWater(amountMl: 500) } },
                        onUndoLastWater: { Task { await model.undoLastWater() } },
                        onLogCustomWater: { isShowingWaterPrompt = true }
                    )

                    CompactMetricCard(
                        icon: "scalemass",
                        iconColor: .purple,
                        title: "Weight",
                        value: state.weightSummary.displayText,
                        actionTitle: "Log",
                        action: { isShowingWeightPrompt = true }
                    )

                    CompactMetricCard(
                        icon: state.workoutSummary.hasWorkout ? "dumbbell.fill" : "dumbbell",
                        iconColor: .green,
                        title: "Workout",
                        value: state.workoutSummary.hasWorkout
                            ? "\(state.workoutSummary.workoutCount) logged"
                            : "None yet",
                        actionTitle: "Open",
                        action: { onOpenTraining?() }
                    )
                }

                FoodTimelinePreview(
                    entries: state.foodEntries,
                    previewLimit: 3,
                    isExpanded: $isFoodTimelineExpanded,
                    onSelectFood: { model.showEditFood($0) },
                    onDeleteFood: { foodEntryPendingDelete = $0 }
                )

                if state.hasMeaningfulLoggedData {
                    DailyReviewCollapsedCard(
                        review: state.dailyReview,
                        isGenerating: model.isGeneratingDailyReview,
                        isExpanded: $isDailyReviewExpanded,
                        onGenerate: {
                            Task { await model.generateDailyReview() }
                        }
                    )
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
}

#Preview {
    let container = try! AppContainer(inMemory: true)
    TodayView(model: container.makeTodayModel())
        .environmentObject(container.refreshCenter)
}
