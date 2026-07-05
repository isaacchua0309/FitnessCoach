//
//  PlanGoalSelectionCard.swift
//  Fitness Coach
//
//  Forma — Legacy alias for Adjust Plan goal option cards.
//

import SwiftUI

typealias PlanGoalSelectionCard = GoalOptionCard

extension GoalOptionCard {

    init(
        presentation: PlanGoalOption,
        isSelected: Bool,
        action: @escaping () -> Void
    ) {
        self.init(
            goal: presentation,
            isSelected: isSelected,
            isRecommended: presentation.isRecommended,
            onSelect: action
        )
    }
}
