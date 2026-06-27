//
//  CoachTodayContextBuilder.swift
//  Fitness Coach
//
//  Forma — Maps today's log into Coach empty-state context (no duplicate nutrition math).
//

import Foundation

enum CoachTodayContextBuilder {

    static func build(
        dailyLog: DailyLog,
        weightLogged: Bool,
        hasWorkout: Bool,
        trainingIntegration: TrainingIntegrationState = .connected,
        trainingDataSource: TrainingDataSource = .appleHealth
    ) -> CoachTodayContextState {
        let (calorieSummary, macroSummary, waterSummary) = TodayDashboardNutritionMapper.maps(from: dailyLog)

        return CoachTodayContextState(
            caloriesLine: caloriesLine(from: calorieSummary),
            proteinLine: proteinLine(
                consumed: macroSummary.protein.consumed,
                target: macroSummary.protein.target
            ),
            waterLine: waterLine(
                consumedMl: waterSummary.consumedMl,
                targetMl: waterSummary.targetMl
            ),
            suggestedFocus: TodayFocusBuilder.focus(
                proteinProgress: macroSummary.protein.progress,
                waterProgress: waterSummary.progress,
                weightLogged: weightLogged,
                hasWorkout: hasWorkout,
                trainingIntegration: trainingIntegration,
                trainingDataSource: trainingDataSource
            )
        )
    }

    // MARK: - Formatting

    static func caloriesLine(from summary: CalorieSummary) -> String {
        "\(summary.consumed) eaten · \(summary.target) target"
    }

    static func proteinLine(consumed: Double, target: Double) -> String {
        "Protein \(TodayTargetsFormatter.macroProgress(consumed: consumed, target: target))"
    }

    static func waterLine(consumedMl: Int, targetMl: Int) -> String {
        "Water \(TodayTargetsFormatter.waterProgress(consumedMl: consumedMl, targetMl: targetMl))"
    }
}
