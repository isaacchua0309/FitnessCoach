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
        latestFoodEntry: FoodEntry?,
        weightLogged: Bool,
        hasWorkout: Bool,
        steps: Int?,
        healthActivityNote: String?,
        healthIntelligence: CoachHealthIntelligenceContext? = nil,
        healthIntelligenceAwarenessAvailable: Bool = false,
        isCoachContextEnabled: Bool = HealthIntelligenceFeatureFlags.shouldCoachLoadHealthIntelligence,
        trainingIntegration: TrainingIntegrationState = .connected,
        trainingDataSource: TrainingDataSource = .appleHealth
    ) -> CoachTodayContextState {
        let (calorieSummary, macroSummary, waterSummary) = TodayDashboardNutritionMapper.maps(from: dailyLog)
        let activity = activityContent(
            latestFoodEntry: latestFoodEntry,
            steps: steps,
            hasWorkout: hasWorkout,
            healthActivityNote: healthActivityNote
        )

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
            activityLines: activity.lines,
            activityHintLine: activity.hintLine,
            suggestedFocus: CoachCompositionPolicy.suggestedFocus(
                healthIntelligence: healthIntelligence,
                proteinProgress: macroSummary.protein.progress,
                waterProgress: waterSummary.progress,
                weightLogged: weightLogged,
                legacyHasWorkout: hasWorkout,
                trainingIntegration: trainingIntegration,
                trainingDataSource: trainingDataSource,
                healthIntelligenceAwarenessAvailable: healthIntelligenceAwarenessAvailable,
                isCoachContextEnabled: isCoachContextEnabled
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

    static func activityContent(
        latestFoodEntry: FoodEntry?,
        steps: Int?,
        hasWorkout: Bool,
        healthActivityNote: String?
    ) -> (lines: [String], hintLine: String?) {
        var lines: [String] = []

        if let latestFoodEntry {
            lines.append(
                FormaProductCopy.Coach.latestMealLine(
                    name: FoodEntryFormFormatter.displayFoodName(latestFoodEntry.name),
                    calories: latestFoodEntry.calories
                )
            )
        }

        if let steps {
            lines.append(FormaProductCopy.Today.Activity.stepsToday(steps))
        } else if healthActivityNote == nil {
            lines.append(FormaProductCopy.Today.Activity.stepsUnavailable)
        }

        if hasWorkout {
            lines.append(FormaProductCopy.Today.Activity.workoutCompletedLine)
        }

        return (lines, healthActivityNote)
    }

    static func healthActivityNote(
        trainingDataSource: TrainingDataSource,
        trainingIntegration: TrainingIntegrationState
    ) -> String? {
        switch trainingDataSource {
        case .unavailable:
            return FormaProductCopy.Today.Activity.healthUnavailableNote
        case .appleHealth:
            guard trainingIntegration.showsConnectionGate else { return nil }
            switch trainingIntegration {
            case .denied, .failed:
                return FormaProductCopy.Today.Activity.healthDeniedNote
            case .notConnected, .unavailable, .requestingPermission, .connected:
                return FormaProductCopy.Today.Activity.healthConnectNote
            }
        }
    }
}
