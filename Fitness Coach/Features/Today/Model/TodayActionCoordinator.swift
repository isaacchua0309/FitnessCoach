//
//  TodayActionCoordinator.swift
//  Fitness Coach
//
//  Forma — Routes Today Next Best Action CTAs to native mutations or Coach when required.
//

import Foundation

@MainActor
final class TodayActionCoordinator: ObservableObject {

    struct LogMealPresentation: Identifiable, Equatable {
        let id = UUID()
        var mealType: MealType?
    }

    @Published private(set) var logMealPresentation: LogMealPresentation?
    @Published private(set) var isPresentingLogWeightSheet = false
    @Published private(set) var lastErrorMessage: String?

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

    func dismissLogMealSheet() {
        logMealPresentation = nil
    }

    func dismissLogWeightSheet() {
        isPresentingLogWeightSheet = false
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
            lastErrorMessage = FormaProductCopy.Error.saveFoodEntry
        }
    }

    func saveWeight(_ weightKg: Double) {
        do {
            _ = try actionCenter.logDailyWeight(weightKg, date: logDate())
            lastErrorMessage = nil
            isPresentingLogWeightSheet = false
        } catch {
            lastErrorMessage = FormaProductCopy.Error.saveWeightEntry
        }
    }

    private func perform(_ route: TodayNextActionRoute) {
        switch route {
        case .logWater(let amountMl):
            do {
                _ = try actionCenter.logWater(amountMl: amountMl, date: logDate())
                lastErrorMessage = nil
            } catch {
                lastErrorMessage = FormaProductCopy.Error.saveWaterEntry
            }
        case .presentLogMeal(let mealType):
            logMealPresentation = LogMealPresentation(mealType: mealType)
        case .presentLogWeight:
            isPresentingLogWeightSheet = true
        case .openCoach(let prefill):
            onOpenCoach?(prefill)
        case .openTrainingInsights:
            onOpenTrainingInsights?()
        case .none:
            break
        }
    }
}
