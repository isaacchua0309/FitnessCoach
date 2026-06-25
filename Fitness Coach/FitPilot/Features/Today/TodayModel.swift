//
//  TodayModel.swift
//  Fitness Coach
//
//  FitPilot AI — Feature model for the Today dashboard.
//

import Combine
import Foundation

@MainActor
final class TodayModel: ObservableObject {

    @Published private(set) var viewState: TodayViewState = .loading
    @Published private(set) var isGeneratingDailyReview = false
    @Published var isShowingFoodEntrySheet = false
    @Published private(set) var editingFoodEntry: FoodEntry?
    @Published private(set) var foodEntryErrorMessage: String?

    private let dailyLogService: DailyLogService
    private let foodLogService: FoodLogService
    private let waterLogService: WaterLogService
    private let weightLogService: WeightLogService
    private let workoutLogService: WorkoutLogService
    private let targetService: TargetService
    private let reviewService: ReviewService
    private let refreshCenter: AppRefreshCenter

    init(
        dailyLogService: DailyLogService,
        foodLogService: FoodLogService,
        waterLogService: WaterLogService,
        weightLogService: WeightLogService,
        workoutLogService: WorkoutLogService,
        targetService: TargetService,
        reviewService: ReviewService,
        refreshCenter: AppRefreshCenter
    ) {
        self.dailyLogService = dailyLogService
        self.foodLogService = foodLogService
        self.waterLogService = waterLogService
        self.weightLogService = weightLogService
        self.workoutLogService = workoutLogService
        self.targetService = targetService
        self.reviewService = reviewService
        self.refreshCenter = refreshCenter
    }

    // MARK: Loading

    func loadToday() async {
        viewState = .loading
        do {
            try loadDashboard()
        } catch ServiceError.missingUserProfile {
            viewState = .empty
        } catch {
            viewState = .error("Could not load today's log.")
        }
    }

    func refresh() async {
        do {
            try loadDashboard()
        } catch ServiceError.missingUserProfile {
            viewState = .empty
        } catch {
            viewState = .error("Could not refresh today's dashboard.")
        }
    }

    // MARK: Actions

    func startNewDay() async {
        do {
            _ = try dailyLogService.startNewDay(weightKg: nil)
            try loadDashboard()
            notifyDataChanged()
        } catch ServiceError.missingUserProfile {
            viewState = .empty
        } catch {
            viewState = .error("Could not start a new day.")
        }
    }

    func addWater(amountMl: Int) async {
        do {
            _ = try waterLogService.addWater(amountMl: amountMl, date: Date())
            try loadDashboard()
            notifyDataChanged()
        } catch ServiceError.missingUserProfile {
            viewState = .empty
        } catch ServiceError.invalidInput(let message) {
            viewState = .error(message)
        } catch {
            viewState = .error("Could not save water entry.")
        }
    }

    func undoLastWater() async {
        do {
            guard try waterLogService.undoLastWaterEntry(date: Date()) != nil else {
                viewState = .error("There was no water entry to undo.")
                return
            }
            try loadDashboard()
            notifyDataChanged()
        } catch ServiceError.missingUserProfile {
            viewState = .empty
        } catch {
            viewState = .error("Could not undo water entry.")
        }
    }

    func logWeight(_ weightKg: Double) async {
        do {
            _ = try weightLogService.logWeight(weightKg, date: Date())
            try loadDashboard()
            notifyDataChanged()
        } catch {
            viewState = .error("Could not log weight.")
        }
    }

    func generateDailyReview() async {
        guard !isGeneratingDailyReview else { return }
        isGeneratingDailyReview = true
        defer { isGeneratingDailyReview = false }

        do {
            _ = try await reviewService.generateDailyReview(for: Date())
            try loadDashboard()
            notifyDataChanged()
        } catch ServiceError.missingUserProfile {
            viewState = .empty
        } catch {
            viewState = .error("Could not generate your daily review.")
        }
    }

    // MARK: Food Entry Sheet

    func showAddFood() {
        foodEntryErrorMessage = nil
        editingFoodEntry = nil
        isShowingFoodEntrySheet = true
    }

    func showEditFood(_ entry: FoodEntry) {
        foodEntryErrorMessage = nil
        editingFoodEntry = entry
        isShowingFoodEntrySheet = true
    }

    func dismissFoodEditor() {
        foodEntryErrorMessage = nil
        editingFoodEntry = nil
        isShowingFoodEntrySheet = false
    }

    func saveFoodEntry(_ formState: FoodEntryFormState) async {
        do {
            if let editingFoodEntry {
                let update = try formState.makeFoodEntryUpdate()
                _ = try foodLogService.editFoodEntry(id: editingFoodEntry.id, update: update)
            } else {
                let draft = try formState.makeFoodDraft()
                _ = try foodLogService.addFoodEntry(draft, date: Date())
            }
            dismissFoodEditor()
            try loadDashboard()
            notifyDataChanged()
        } catch let error as FoodEntryFormError {
            foodEntryErrorMessage = error.localizedDescription
        } catch ServiceError.invalidInput(let message) {
            foodEntryErrorMessage = message
        } catch ServiceError.foodEntryNotFound {
            foodEntryErrorMessage = "That food entry could not be found."
        } catch ServiceError.missingUserProfile {
            viewState = .empty
            dismissFoodEditor()
        } catch {
            foodEntryErrorMessage = "Could not save food entry."
        }
    }

    func deleteFoodEntry(_ entry: FoodEntry) async {
        do {
            try foodLogService.deleteFoodEntry(id: entry.id)
            if editingFoodEntry?.id == entry.id {
                dismissFoodEditor()
            }
            try loadDashboard()
            notifyDataChanged()
        } catch ServiceError.foodEntryNotFound {
            if isShowingFoodEntrySheet {
                foodEntryErrorMessage = "That food entry could not be found."
            } else {
                viewState = .error("That food entry could not be found.")
            }
        } catch {
            if isShowingFoodEntrySheet {
                foodEntryErrorMessage = "Could not delete food entry."
            } else {
                viewState = .error("Could not delete food entry.")
            }
        }
    }

    // MARK: State Building

    private func loadDashboard() throws {
        let dailyLog = try dailyLogService.getTodayLog()
        let foodEntries = try foodLogService.getFoodEntries(for: dailyLog.date)
        let workouts = try workoutLogService.getWorkouts(for: dailyLog.date)
        let latestWeight = dailyLog.weightKg == nil ? try weightLogService.getLatestWeight() : nil
        let dailyReview = try reviewService.getDailyReview(for: dailyLog.date)

        viewState = .loaded(
            makeDashboardState(
                dailyLog: dailyLog,
                foodEntries: foodEntries,
                workouts: workouts,
                latestWeight: latestWeight,
                dailyReview: dailyReview
            )
        )
    }

    private func makeDashboardState(
        dailyLog: DailyLog,
        foodEntries: [FoodEntry],
        workouts: [WorkoutEntry],
        latestWeight: WeightEntry?,
        dailyReview: DailyReview?
    ) -> TodayDashboardState {
        let targets = MacroCalculator.macroTargets(from: dailyLog.targets)
        let remaining = MacroCalculator.remaining(targets: targets, totals: dailyLog.totals)

        let calorieSummary = CalorieSummary(
            consumed: dailyLog.totals.calories,
            target: targets.calories,
            remaining: remaining.calories,
            progress: MacroCalculator.calorieProgress(totals: dailyLog.totals, targets: targets),
            isOverTarget: MacroCalculator.isOverCalories(totals: dailyLog.totals, targets: targets)
        )

        let macroSummary = MacroSummary(
            protein: MacroProgress(
                consumed: dailyLog.totals.protein,
                target: targets.protein,
                remaining: remaining.protein,
                progress: MacroCalculator.proteinProgress(totals: dailyLog.totals, targets: targets)
            ),
            carbs: MacroProgress(
                consumed: dailyLog.totals.carbs,
                target: targets.carbs,
                remaining: remaining.carbs,
                progress: MacroCalculator.progress(consumed: dailyLog.totals.carbs, target: targets.carbs)
            ),
            fat: MacroProgress(
                consumed: dailyLog.totals.fat,
                target: targets.fat,
                remaining: remaining.fat,
                progress: MacroCalculator.progress(consumed: dailyLog.totals.fat, target: targets.fat)
            )
        )

        let waterSummary = WaterSummary(
            consumedMl: dailyLog.waterConsumedMl,
            targetMl: dailyLog.targets.waterTargetMl,
            remainingMl: WaterTargetCalculator.remainingMl(
                consumedMl: dailyLog.waterConsumedMl,
                targetMl: dailyLog.targets.waterTargetMl
            ),
            progress: WaterTargetCalculator.progress(
                consumedMl: dailyLog.waterConsumedMl,
                targetMl: dailyLog.targets.waterTargetMl
            )
        )

        let displayWeight = dailyLog.weightKg ?? latestWeight?.weightKg
        let weightSummary = TodayWeightSummary(
            weightKg: displayWeight,
            displayText: displayWeight.map { String(format: "%.2f kg", $0) } ?? "No weight logged yet"
        )

        let workoutSummary = TodayWorkoutSummary(
            workoutCaloriesBurned: dailyLog.workoutCaloriesBurned,
            workoutCount: workouts.count,
            hasWorkout: !workouts.isEmpty
        )

        return TodayDashboardState(
            date: dailyLog.date,
            calorieSummary: calorieSummary,
            macroSummary: macroSummary,
            waterSummary: waterSummary,
            weightSummary: weightSummary,
            stepsSummary: dailyLog.steps.map { StepsSummary(steps: $0) },
            workoutSummary: workoutSummary,
            foodEntries: foodEntries,
            hasDailyLog: true,
            dailyReview: dailyReview,
            coachingNote: coachingNote(
                calorieSummary: calorieSummary,
                macroSummary: macroSummary,
                waterSummary: waterSummary
            )
        )
    }

    private func coachingNote(
        calorieSummary: CalorieSummary,
        macroSummary: MacroSummary,
        waterSummary: WaterSummary
    ) -> String {
        if calorieSummary.isOverTarget {
            return "You are over target today, but one day does not define progress. Keep logging honestly."
        }
        if macroSummary.protein.remaining > 40 {
            return "Prioritize lean protein in your next meal."
        }
        if waterSummary.remainingMl > 1000 {
            return "Try to pace your water earlier in the day."
        }
        return "You are on track today. Keep logging meals and water consistently."
    }

    private func notifyDataChanged() {
        refreshCenter.notifyDataChanged()
    }
}
