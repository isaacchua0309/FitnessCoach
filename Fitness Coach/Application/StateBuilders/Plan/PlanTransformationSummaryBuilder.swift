//
//  PlanTransformationSummaryBuilder.swift
//  Fitness Coach
//
//  Forma — Transformation summary for the Edit Plan target step.
//

import Foundation

struct PlanTransformationSummaryState: Equatable, Sendable {
    let currentWeight: String
    let targetWeight: String
    let totalChange: String
    let estimatedDuration: String?
    let estimatedFinish: String?
    let progressFraction: Double
    let isComplete: Bool
}

enum PlanTransformationSummaryBuilder {

    static func build(
        projection: PlanProjection,
        currentWeightKg: Double?,
        goalWeightKg: Double?,
        goalType: PlanGoalType
    ) -> PlanTransformationSummaryState {
        let copy = FormaProductCopy.PlanEditTarget.self
        let current = projection.currentWeightDisplay
        let target = projection.targetWeightDisplay

        let totalChange: String
        if let label = projection.weightChangeLabel {
            totalChange = label
        } else if goalType == .maintain {
            totalChange = FormaProductCopy.PlanEditHero.maintainingTarget
        } else {
            totalChange = copy.unavailable
        }

        let duration = projection.estimatedWeeks.map {
            FormaProductCopy.PlanEditTarget.estimatedDuration(weeks: $0)
        }

        let finish = projection.estimatedCompletionLabel?
            .replacingOccurrences(of: "Estimated finish: ", with: "")
            .replacingOccurrences(of: ".", with: "")

        let progress = progressFraction(
            currentWeightKg: currentWeightKg,
            goalWeightKg: goalWeightKg
        )

        let isComplete = currentWeightKg != nil
            && goalWeightKg != nil
            && current != FormaProductCopy.PlanEditHero.weightUnavailable
            && target != FormaProductCopy.PlanEditHero.weightUnavailable

        return PlanTransformationSummaryState(
            currentWeight: current,
            targetWeight: target,
            totalChange: totalChange,
            estimatedDuration: duration,
            estimatedFinish: finish,
            progressFraction: progress,
            isComplete: isComplete
        )
    }

    private static func progressFraction(
        currentWeightKg: Double?,
        goalWeightKg: Double?
    ) -> Double {
        guard let currentWeightKg,
              let goalWeightKg,
              abs(goalWeightKg - currentWeightKg) > FormaCalculationConstants.goalDirectionEpsilonKg
        else {
            return 0
        }
        // Planning stage — journey starts at current weight.
        return 0
    }
}
