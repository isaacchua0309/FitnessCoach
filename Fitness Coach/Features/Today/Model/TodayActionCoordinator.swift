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
    private var analyticsSnapshot: TodayAnalyticsSnapshot = .empty

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

    // MARK: - Analytics context

    func updateAnalyticsContext(from state: TodayDashboardState, healthConnected: Bool) {
        analyticsSnapshot = TodayAnalyticsContextBuilder.snapshot(
            from: state,
            healthConnected: healthConnected
        )
    }

    func logTodayViewed() {
        log(.viewed)
    }

    func logNextActionViewed(for action: NextBestActionState) {
        log(
            .nextActionViewed,
            reason: TodayNextActionFormatting.analyticsReason(action.reason)
        )
    }

    func logGoalConnectionTapped(destination: TodayGoalConnectionDestination) {
        log(
            .goalConnectionTapped,
            actionType: "goal_connection",
            destination: TodayAnalyticsContextBuilder.goalConnectionDestination(destination)
        )
    }

    // MARK: - Next Best Action

    func handleCTA(_ cta: NextBestActionCTA, from action: NextBestActionState) {
        let route = TodayNextActionFormatting.route(for: cta)
        log(
            .nextActionTapped,
            actionType: "next_best_action",
            reason: TodayNextActionFormatting.analyticsReason(action.reason),
            cta: TodayNextActionFormatting.analyticsCTA(cta),
            route: TodayNextActionFormatting.analyticsRoute(route)
        )
        perform(route)
    }

    // MARK: - Quick actions

    func performQuickAction(_ kind: TodayQuickActionKind) {
        guard TodayQuickActionPolicy.isVisible(kind) else { return }

        let route = route(for: kind)
        log(
            .quickActionTapped,
            actionType: "quick_action",
            route: TodayNextActionFormatting.analyticsRoute(route),
            action: kind.rawValue
        )

        perform(route)
    }

    func logMeal(for mealType: MealType) {
        perform(.presentLogMeal(mealType: mealType))
    }

    func openEditFood(_ entry: FoodEntry) {
        foodEditErrorMessage = nil
        editFoodPresentation = EditFoodPresentation(entry: entry)
        log(
            .mealEditStarted,
            actionType: "edit_meal",
            mealType: TodayAnalyticsContextBuilder.mealTypeAction(entry.mealType)
        )
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
            TodayHaptics.deleteSucceeded()
            log(
                .mealDeleted,
                actionType: "delete_meal",
                mealType: TodayAnalyticsContextBuilder.mealTypeAction(entry.mealType)
            )
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
            TodayHaptics.saveSucceeded()
            log(
                .mealEditSaved,
                actionType: "edit_meal",
                mealType: TodayAnalyticsContextBuilder.mealTypeAction(formState.mealType)
            )
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
            TodayHaptics.saveSucceeded()
            log(
                .logMealSaved,
                actionType: "log_meal",
                mealType: TodayAnalyticsContextBuilder.mealTypeAction(formState.mealType)
            )
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
            TodayHaptics.saveSucceeded()
            log(.weightLogged, actionType: "log_weight")
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
                TodayHaptics.saveSucceeded()
                log(
                    .waterAdded,
                    actionType: "add_water",
                    waterAmountBucket: TodayAnalyticsContextBuilder.waterAmountBucket(amountMl)
                )
            } catch {
                lastErrorMessage = FormaProductCopy.Error.checkInputs
            }
        case .presentLogMeal(let mealType):
            log(
                .logMealStarted,
                actionType: "log_meal",
                mealType: TodayAnalyticsContextBuilder.mealTypeAction(mealType)
            )
            logMealPresentation = LogMealPresentation(mealType: mealType)
        case .presentLogWeight:
            isPresentingLogWeightSheet = true
        case .presentAddWater:
            isPresentingAddWaterSheet = true
        case .openCoach(let prefill):
            if prefill == TodayCoachPrompt.scanFood {
                log(.scanFoodTapped, actionType: "scan_food", route: "open_coach")
            }
            onOpenCoach?(prefill)
        case .openTrainingInsights:
            onOpenTrainingInsights?()
        case .none:
            break
        }
    }

    // MARK: - Analytics helpers

    private func log(
        _ event: TodayAnalyticsEvent,
        actionType: String? = nil,
        reason: String? = nil,
        cta: String? = nil,
        route: String? = nil,
        action: String? = nil,
        mealType: String? = nil,
        waterAmountBucket: String? = nil,
        destination: String? = nil
    ) {
        analyticsLogger.log(
            event,
            properties: .from(
                snapshot: analyticsSnapshot,
                actionType: actionType,
                reason: reason,
                cta: cta,
                route: route,
                action: action,
                mealType: mealType,
                waterAmountBucket: waterAmountBucket,
                destination: destination
            )
        )
    }
}
