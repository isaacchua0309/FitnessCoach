//
//  TodayGoalsBuilder.swift
//  Fitness Coach
//
//  FitPilot AI — Read-only daily goal status from dashboard state.
//

import Foundation

struct TodayGoalItem: Identifiable, Equatable {
    enum Kind: String, Equatable {
        case weight
        case protein
        case water
        case workout
    }

    var id: String { kind.rawValue }
    let kind: Kind
    var label: String
    var isComplete: Bool
}

enum TodayGoalsBuilder {

    static func goals(from state: TodayDashboardState) -> [TodayGoalItem] {
        return [
            TodayGoalItem(
                kind: .weight,
                label: state.weightSummary.weightKg != nil ? "Weight logged" : "Weight not logged",
                isComplete: state.weightSummary.weightKg != nil
            ),
            TodayGoalItem(
                kind: .protein,
                label: state.macroSummary.protein.progress >= 0.9
                    ? "Protein goal met"
                    : "Protein · \(formatGrams(state.macroSummary.protein.consumed)) / \(formatGrams(state.macroSummary.protein.target))",
                isComplete: state.macroSummary.protein.progress >= 0.9
            ),
            TodayGoalItem(
                kind: .water,
                label: state.waterSummary.progress >= 0.8
                    ? "Hydration on track"
                    : "Water · \(state.waterSummary.consumedMl) / \(state.waterSummary.targetMl) ml",
                isComplete: state.waterSummary.progress >= 0.8
            ),
            TodayGoalItem(
                kind: .workout,
                label: state.workoutSummary.hasWorkout ? "Workout logged" : "No workout logged",
                isComplete: state.workoutSummary.hasWorkout
            )
        ]
    }

    private static func formatGrams(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value))g"
            : String(format: "%.0fg", value)
    }
}
