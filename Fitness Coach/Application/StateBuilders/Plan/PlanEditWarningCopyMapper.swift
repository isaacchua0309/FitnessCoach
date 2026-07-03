//
//  PlanEditWarningCopyMapper.swift
//  Fitness Coach
//
//  Forma — Maps calculation warning codes to Edit Plan user-facing copy.
//

import Foundation

struct PlanEditReviewWarning: Equatable, Sendable {
    let title: String
    let body: String
}

enum PlanEditWarningCopyMapper {

    static func userFacingWarning(
        warningCode: String?,
        isAggressive: Bool = false,
        projection: PlanProjection? = nil
    ) -> PlanEditReviewWarning? {
        if let warningCode, let mapped = mappedWarning(for: warningCode) {
            return mapped
        }
        if isAggressive {
            return aggressiveDeficitWarning()
        }
        if let projection, shouldWarn(for: projection) {
            return aggressiveDeficitWarning()
        }
        return nil
    }

    static func aggressiveDeficitWarning() -> PlanEditReviewWarning {
        let copy = FormaProductCopy.PlanEditReview.self
        return PlanEditReviewWarning(
            title: copy.aggressiveDeficitTitle,
            body: copy.aggressiveDeficitBody
        )
    }

    private static func mappedWarning(for code: String) -> PlanEditReviewWarning? {
        switch code {
        case "aggressiveDeficit":
            return aggressiveDeficitWarning()
        default:
            return nil
        }
    }

    private static func shouldWarn(for projection: PlanProjection) -> Bool {
        projection.difficultyLabel == PlanEditDifficultyLabelBuilder.fasterCutLabel
    }
}
