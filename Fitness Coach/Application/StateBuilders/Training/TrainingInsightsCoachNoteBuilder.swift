//
//  TrainingInsightsCoachNoteBuilder.swift
//  Fitness Coach
//
//  Forma — Deterministic coach note for Training Insights (no AI).
//

import Foundation

enum TrainingInsightsCoachNoteBuilder {

    static func note(weeklyWorkoutCount: Int) -> String {
        switch weeklyWorkoutCount {
        case 0:
            return "No workouts found yet. Once Apple Fitness records one, Forma will reflect it here."
        case 1:
            return "You trained once this week. Keep your next session simple and recover well."
        case 2:
            return "You trained twice this week. Keep your next session simple and recover well."
        default:
            return "You trained \(weeklyWorkoutCount) times this week. Steady consistency builds results."
        }
    }
}
