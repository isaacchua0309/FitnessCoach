//
//  PlanGoalSelectionBuilder.swift
//  Fitness Coach
//
//  Forma — Presentation model for Edit Plan goal selection cards.
//

import Foundation

struct PlanGoalOptionPresentation: Equatable, Identifiable, Sendable {
    var id: PlanGoalType { goalType }
    let goalType: PlanGoalType
    let title: String
    let explanation: String
    let outcomePreview: String
    let iconSystemName: String
    let isRecommended: Bool
}

enum PlanGoalSelectionBuilder {

    static func options(recommendedGoal: PlanGoalType) -> [PlanGoalOptionPresentation] {
        PlanGoalType.allCases.map { goalType in
            presentation(for: goalType, isRecommended: goalType == recommendedGoal)
        }
    }

    static func recommendedGoal(for profile: UserProfile) -> PlanGoalType {
        PlanStateBuilder.goalType(for: profile)
    }

    static func displayTitle(for goalType: PlanGoalType) -> String {
        presentation(for: goalType, isRecommended: false).title
    }

    private static func presentation(
        for goalType: PlanGoalType,
        isRecommended: Bool
    ) -> PlanGoalOptionPresentation {
        let copy = FormaProductCopy.PlanEditGoal.self
        switch goalType {
        case .loseFat:
            return PlanGoalOptionPresentation(
                goalType: goalType,
                title: copy.loseFatTitle,
                explanation: copy.loseFatExplanation,
                outcomePreview: copy.loseFatOutcome,
                iconSystemName: "flame.fill",
                isRecommended: isRecommended
            )
        case .maintain:
            return PlanGoalOptionPresentation(
                goalType: goalType,
                title: copy.maintainTitle,
                explanation: copy.maintainExplanation,
                outcomePreview: copy.maintainOutcome,
                iconSystemName: "scope",
                isRecommended: isRecommended
            )
        case .gainMuscle:
            return PlanGoalOptionPresentation(
                goalType: goalType,
                title: copy.gainMuscleTitle,
                explanation: copy.gainMuscleExplanation,
                outcomePreview: copy.gainMuscleOutcome,
                iconSystemName: "arrow.up.forward.circle.fill",
                isRecommended: isRecommended
            )
        }
    }
}
