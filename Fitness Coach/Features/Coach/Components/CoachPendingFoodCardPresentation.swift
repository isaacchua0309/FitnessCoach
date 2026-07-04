//
//  CoachPendingFoodCardPresentation.swift
//  Fitness Coach
//
//  FitPilot AI — Pending food card layout mode derived from Coach state.
//

import Foundation

enum CoachPendingFoodCardPresentation: Equatable {
    case hidden
    case expanded
    case compact
}

enum CoachPendingFoodCardPresentationResolver {

    static func presentation(
        pendingConfirmation: CoachPendingConfirmation?,
        isInputFocused: Bool
    ) -> CoachPendingFoodCardPresentation {
        guard pendingConfirmation != nil else { return .hidden }
        return isInputFocused ? .compact : .expanded
    }

    static func cardAccessibilityIdentifier(
        for presentation: CoachPendingFoodCardPresentation
    ) -> String? {
        switch presentation {
        case .hidden:
            return nil
        case .expanded:
            return CoachAccessibilityIdentifier.pendingFoodCardExpanded
        case .compact:
            return CoachAccessibilityIdentifier.pendingFoodCardCompact
        }
    }
}
