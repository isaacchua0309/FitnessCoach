//
//  TrainingInsightsConsistencyNoteBuilder.swift
//  Fitness Coach
//
//  Forma — Calm consistency copy for Training Insights (no AI).
//

import Foundation

enum TrainingInsightsConsistencyNoteBuilder {

    static func note(for consistency: TrainingInsightsConsistencySummary) -> String {
        if consistency.workoutDays28 == 0 {
            return "Your training pattern will appear here as Apple Health records workouts."
        }
        if consistency.workoutDays14 >= 3 {
            return "You have been training regularly over the last two weeks."
        }
        if consistency.workoutDays7 >= 1 {
            return "Recent activity is showing up — steady days add up over time."
        }
        return "Training from earlier weeks still contributes to your longer-term pattern."
    }
}
