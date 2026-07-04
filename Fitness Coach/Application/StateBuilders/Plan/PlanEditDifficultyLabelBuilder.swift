//
//  PlanEditDifficultyLabelBuilder.swift
//  Fitness Coach
//
//  Forma — User-facing difficulty labels for Edit Plan projections.
//

import Foundation

enum PlanEditDifficultyLabelBuilder {

    static func label(
        goalDirection: PlanGoalDirection,
        paceChoice: WeightLossPaceChoice
    ) -> String {
        let copy = FormaProductCopy.PlanEditDifficulty.self
        switch goalDirection {
        case .maintain:
            return copy.maintenance
        case .gain:
            return copy.leanGain
        case .cut:
            switch paceChoice {
            case .gentle:
                return copy.gentleCut
            case .moderate:
                return copy.moderateCut
            case .aggressive:
                return copy.fasterCut
            case .advanced:
                return copy.customCut
            }
        }
    }

    static var fasterCutLabel: String {
        FormaProductCopy.PlanEditDifficulty.fasterCut
    }
}
