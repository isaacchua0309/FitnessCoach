//
//  PlanEditHeroStateBuilder.swift
//  Fitness Coach
//
//  Forma — Live hero summary for the Edit Plan shell.
//

import Foundation

struct PlanEditHeroState: Equatable, Sendable {
    let motivationalLine: String
    let goalLabel: String
    let goalValue: String
    let currentWeightLabel: String
    let currentWeight: String
    let targetWeightLabel: String
    let targetWeight: String
    let totalChangeLine: String?
    let estimatedFinishLine: String?
    let accessibilitySummary: String
}

enum PlanEditHeroStateBuilder {

    static func build(projection: PlanProjection) -> PlanEditHeroState {
        let copy = FormaProductCopy.PlanEditHero.self
        let motivationalLine = motivationalLine(for: projection.goalLabel)

        return PlanEditHeroState(
            motivationalLine: motivationalLine,
            goalLabel: copy.goalLabel,
            goalValue: projection.goalLabel,
            currentWeightLabel: copy.currentWeightLabel,
            currentWeight: projection.currentWeightDisplay,
            targetWeightLabel: copy.targetWeightLabel,
            targetWeight: projection.targetWeightDisplay,
            totalChangeLine: projection.weightChangeLabel,
            estimatedFinishLine: projection.estimatedCompletionLabel,
            accessibilitySummary: accessibilitySummary(
                motivationalLine: motivationalLine,
                goalLabel: copy.goalLabel,
                goalValue: projection.goalLabel,
                currentWeightLabel: copy.currentWeightLabel,
                currentWeight: projection.currentWeightDisplay,
                targetWeightLabel: copy.targetWeightLabel,
                targetWeight: projection.targetWeightDisplay,
                totalChangeLine: projection.weightChangeLabel,
                estimatedFinishLine: projection.estimatedCompletionLabel
            )
        )
    }

    private static func motivationalLine(for goalLabel: String) -> String {
        switch goalLabel {
        case PlanGoalType.loseFat.rawValue:
            return FormaProductCopy.PlanEditHero.motivationalFatLoss
        case PlanGoalType.maintain.rawValue:
            return FormaProductCopy.PlanEditHero.motivationalMaintenance
        case PlanGoalType.gainMuscle.rawValue:
            return FormaProductCopy.PlanEditHero.motivationalMuscleGain
        default:
            return FormaProductCopy.PlanEditHero.motivationalFatLoss
        }
    }

    private static func accessibilitySummary(
        motivationalLine: String,
        goalLabel: String,
        goalValue: String,
        currentWeightLabel: String,
        currentWeight: String,
        targetWeightLabel: String,
        targetWeight: String,
        totalChangeLine: String?,
        estimatedFinishLine: String?
    ) -> String {
        var parts = [
            motivationalLine,
            "\(goalLabel), \(goalValue)",
            "\(currentWeightLabel), \(currentWeight)",
            "\(targetWeightLabel), \(targetWeight)"
        ]
        if let totalChangeLine {
            parts.append(totalChangeLine)
        }
        if let estimatedFinishLine {
            parts.append(estimatedFinishLine)
        }
        return parts.joined(separator: ". ")
    }
}
