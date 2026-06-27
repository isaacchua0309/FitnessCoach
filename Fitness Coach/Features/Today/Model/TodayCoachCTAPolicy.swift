//
//  TodayCoachCTAPolicy.swift
//  Fitness Coach
//
//  Forma — When Today shows the generic Coach CTA vs section-owned actions.
//

import Foundation

enum TodayCoachCTAPolicy {

    /// Generic “Update today with Coach” only when Meals and Next Actions have no better CTA.
    static func showsGenericCoachCTA(
        foodEntries: [FoodEntry],
        goals: [TodayGoalItem]
    ) -> Bool {
        if foodEntries.isEmpty {
            return false
        }

        let hasCoachNextAction = goals.contains { goal in
            if case .coach = goal.tapAction { return true }
            return false
        }
        return !hasCoachNextAction
    }
}
