//
//  TodayActionCoordinator.swift
//  Fitness Coach
//
//  Forma — Routes Today actions to native mutations or Coach when required.
//

import Combine
import Foundation

@MainActor
final class TodayActionCoordinator: ObservableObject {

    static let defaultWaterPresetAmountsMl = [250, 500, 750, 1_000]

    struct LogMealPresentation: Identifiable, Equatable {
        let id = UUID()
        var mealType: MealType?
    }

    struct EditFoodPresentation: Identifiable, Equatable {
        var id: UUID { entry.id }
        let entry: FoodEntry
    }

    @Published var logMealPresentation: LogMealPresentation?
    @Published var editFoodPresentation: EditFoodPresentation?
    @Published var pendingDeleteFoodEntry: FoodEntry?
    @Published var isPresentingLogWeightSheet = false
    @Published var isPresentingAddWaterSheet = false
    @Published private(set) var lastErrorMessage: String?
    @Published private(set) var foodEditErrorMessage: String?

    private let actionCenter: FitnessActionCenter
    private let analyticsLogger: any TodayAnalyticsLogging
    private let logDate: () -> Date

    var onOpenCoach: ((String?) -> Void)?
    var onOpenTrainingInsights: (() -> Void)?

    init(
        actionCenter: FitnessActionCenter,
        analyticsLogger: any TodayAnalyticsLogging = NoOpTodayAnalyticsLogger(),
        logDate: @escaping () -> Date = { Date() }
    ) {
        self.actionCenter = actionCenter
        self.analyticsLogger = analyticsLogger
        self.logDate = logDate
    }

    // MARK: - Next Best Action

    func handleCTA(_ cta: NextBestActionCTA, from action: NextBestActionState) {
        let route = TodayNextActionFormatting.route(for: cta)
        analyticsLogger.log(
            .nextActionCTATapped,
            properties: TodayAnalyticsProperties(
                reason: TodayNextActionFormatting.analyticsReason(action.reason),
                cta: TodayNextActionFormatting.analyticsCTA(cta),
                route: TodayNextActionFormatting.analyticsRoute(route)
            )
        )
        perform(route)
    }

    // MARK: - Quick actions

    func performQuickAction(_ kind: TodayQuickActionKind) {
        guard TodayQuickActionPolicy.isVisible(kind) else { return }

        analyticsLogger.log(
            .quickActionTapped,
            properties: TodayAnalyticsProperties(
                route: TodayNextActionFormatting.analyticsRoute(route(for: kind)),
                action: kind.rawValue
            )
        )

        perform(route(for: kind))
    }

    func logMeal(for mealType: MealType) {
        perform(.presentLogMeal(mealType: mealType))
    }

    func openEditFood(_ entry: FoodEntry) {
        foodEditErrorMessage = nil
        editFoodPresentation = EditFoodPresentation(entry: entry)
    }

    func dismissEditFoodSheet() {
        editFoodPresentation = nil
        foodEditErrorMessage = nil
    }

    func requestDeleteFood(_ entry: FoodEntry) {
        pendingDeleteFoodEntry = entry
    }

    func cancelDeleteFood() {
        pendingDeleteFoodEntry = nil
    }

    func confirmDeleteFood() {
        guard let entry = pendingDeleteFoodEntry else { return }
        do {
            try actionCenter.deleteFoodEntry(id: entry.id)
            foodEditErrorMessage = nil
            pendingDeleteFoodEntry = nil
            if editFoodPresentation?.entry.id == entry.id {
                editFoodPresentation = nil
            }
        } catch {
            foodEditErrorMessage = FormaProductCopy.Error.checkInputs
            pendingDeleteFoodEntry = nil
        }
    }

    func saveFoodEdit(from formState: FoodEntryFormState) {
        guard let presentation = editFoodPresentation else { return }
        do {
            var update = try formState.makeFoodEntryUpdate()
            if presentation.entry.source != .manual {
                update.source = .corrected
            }
            _ = try actionCenter.editFoodEntry(id: presentation.entry.id, update: update)
            foodEditErrorMessage = nil
            editFoodPresentation = nil
        } catch let error as FoodEntryFormError {
            foodEditErrorMessage = error.localizedDescription
        } catch {
            foodEditErrorMessage = FormaProductCopy.Error.checkInputs
        }
    }

    func dismissLogMealSheet() {
        logMealPresentation = nil
    }

    func dismissLogWeightSheet() {
        isPresentingLogWeightSheet = false
    }

    func dismissAddWaterSheet() {
        isPresentingAddWaterSheet = false
    }

    func saveMeal(from formState: FoodEntryFormState) {
        do {
            let draft = try formState.makeFoodDraft()
            _ = try actionCenter.logFood(draft, date: logDate())
            lastErrorMessage = nil
            logMealPresentation = nil
        } catch let error as FoodEntryFormError {
            lastErrorMessage = error.localizedDescription
        } catch {
            lastErrorMessage = FormaProductCopy.Error.checkInputs
        }
    }

    func saveWeight(_ weightKg: Double) {
        do {
            _ = try actionCenter.logDailyWeight(weightKg, date: logDate())
            lastErrorMessage = nil
            isPresentingLogWeightSheet = false
        } catch {
            lastErrorMessage = FormaProductCopy.Error.checkInputs
        }
    }

    func addWater(amountMl: Int) {
        perform(.logWater(amountMl: amountMl))
        isPresentingAddWaterSheet = false
    }

    // MARK: - Routing

    private func route(for kind: TodayQuickActionKind) -> TodayNextActionRoute {
        switch kind {
        case .scanFood:
            return .openCoach(TodayCoachPrompt.scanFood)
        case .manualEntry:
            return .presentLogMeal(mealType: nil)
        case .addWater:
            return .presentAddWater
        case .logWeight:
            return .presentLogWeight
        case .askCoach:
            return .openCoach(nil)
        }
    }

    private func perform(_ route: TodayNextActionRoute) {
        switch route {
        case .logWater(let amountMl):
            do {
                _ = try actionCenter.logWater(amountMl: amountMl, date: logDate())
                lastErrorMessage = nil
            } catch {
                lastErrorMessage = FormaProductCopy.Error.checkInputs
            }
        case .presentLogMeal(let mealType):
            logMealPresentation = LogMealPresentation(mealType: mealType)
        case .presentLogWeight:
            isPresentingLogWeightSheet = true
        case .presentAddWater:
            isPresentingAddWaterSheet = true
        case .openCoach(let prefill):
            onOpenCoach?(prefill)
        case .openTrainingInsights:
            onOpenTrainingInsights?()
        case .none:
            break
        }
    }
}
