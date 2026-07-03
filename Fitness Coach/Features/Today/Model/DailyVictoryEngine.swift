//
//  DailyVictoryEngine.swift
//  Fitness Coach
//
//  Deterministic daily victory selection for Today (no AI).
//

import Foundation

enum TodayVictoryKind: Equatable, Sendable {
    case hidden
    case startEncouragement
    case firstMeal
    case proteinTarget
    case waterTarget
    case workoutCompleted
    case caloriesOnTarget
    case showedUp
}

struct DailyVictoryInput: Equatable {
    var foodEntries: [FoodEntry]
    var proteinProgress: MacroProgress
    var waterSummary: WaterSummary
    var calorieSummary: CalorieSummary
    var workoutSummary: TodayWorkoutSummary
    var activityContext: TodayActivityContext
    var weightLoggedToday: Bool
}

enum DailyVictoryEngine {

    static let proteinTargetThreshold = 1.0
    static let waterTargetThreshold = 1.0

    static func resolve(_ input: DailyVictoryInput) -> TodayVictoryState {
        guard hasMeaningfulAction(input) else {
            return state(for: .startEncouragement)
        }

        if isCaloriesOnTarget(input) {
            return state(for: .caloriesOnTarget)
        }
        if isProteinTargetReached(input) {
            return state(for: .proteinTarget)
        }
        if isWaterTargetReached(input) {
            return state(for: .waterTarget)
        }
        if hasWorkoutToday(input) {
            return state(for: .workoutCompleted)
        }
        if isFirstMealLogged(input) {
            return state(for: .firstMeal)
        }

        return state(for: .showedUp)
    }

    static func hasMeaningfulAction(_ input: DailyVictoryInput) -> Bool {
        !input.foodEntries.isEmpty
            || input.weightLoggedToday
            || input.waterSummary.consumedMl > 0
            || hasWorkoutToday(input)
    }

    static func isCaloriesOnTarget(_ input: DailyVictoryInput) -> Bool {
        guard !input.calorieSummary.isOverTarget else { return false }
        guard input.calorieSummary.consumed > 0 else { return false }
        return TodayPresentationBuilder.isCalorieTargetMet(input.calorieSummary)
    }

    static func isProteinTargetReached(_ input: DailyVictoryInput) -> Bool {
        let protein = input.proteinProgress
        guard protein.target > 0 else { return false }
        return protein.progress >= proteinTargetThreshold || protein.remaining <= 0
    }

    static func isWaterTargetReached(_ input: DailyVictoryInput) -> Bool {
        let water = input.waterSummary
        guard water.targetMl > 0 else { return false }
        return water.progress >= waterTargetThreshold || water.consumedMl >= water.targetMl
    }

    static func hasWorkoutToday(_ input: DailyVictoryInput) -> Bool {
        input.workoutSummary.hasWorkout || (input.activityContext.appleHealthWorkoutCount ?? 0) > 0
    }

    static func isFirstMealLogged(_ input: DailyVictoryInput) -> Bool {
        input.foodEntries.count == 1
    }

    private static func state(for kind: TodayVictoryKind) -> TodayVictoryState {
        let message: String
        switch kind {
        case .hidden:
            message = ""
        case .startEncouragement:
            message = FormaProductCopy.Today.Victory.startEncouragement
        case .firstMeal:
            message = FormaProductCopy.Today.Victory.firstMeal
        case .proteinTarget:
            message = FormaProductCopy.Today.Victory.proteinTarget
        case .waterTarget:
            message = FormaProductCopy.Today.Victory.waterTarget
        case .workoutCompleted:
            message = FormaProductCopy.Today.Victory.workoutCompleted
        case .caloriesOnTarget:
            message = FormaProductCopy.Today.Victory.caloriesOnTarget
        case .showedUp:
            message = FormaProductCopy.Today.Victory.showedUp
        }

        return TodayVictoryState(kind: kind, message: message)
    }
}
