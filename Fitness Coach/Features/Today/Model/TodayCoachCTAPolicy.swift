//
//  TodayCoachCTAPolicy.swift
//  Fitness Coach
//
//  Forma — When Today shows the generic Coach CTA vs section-owned actions.
//

import Foundation

enum TodayCoachCTAPolicy {

    /// Generic “Update today with Coach” only when meals exist and the next-best action has no Coach CTA.
    static func showsGenericCoachCTA(
        foodEntries: [FoodEntry],
        nextBestAction: NextBestActionState
    ) -> Bool {
        if foodEntries.isEmpty {
            return false
        }

        switch nextBestAction.primaryCTA {
        case .logMeal, .scanFood, .addWater, .logWeight:
            return false
        case .openHealth, .reviewToday, .none:
            return true
        }
    }
}
