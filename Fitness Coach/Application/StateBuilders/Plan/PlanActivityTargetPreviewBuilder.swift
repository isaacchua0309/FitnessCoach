//
//  PlanActivityTargetPreviewBuilder.swift
//  Fitness Coach
//
//  Forma — Live target preview for Edit Plan activity step.
//

import Foundation

struct PlanActivityTargetPreviewState: Equatable, Sendable {
    let maintenanceCalories: String?
    let targetCalories: String?
    let proteinTarget: String?
    let trainingAssumption: String
    let isComplete: Bool
}

enum PlanActivityTargetPreviewBuilder {

    static func build(
        projection: PlanProjection,
        formState: PlanFormState
    ) -> PlanActivityTargetPreviewState {
        let copy = FormaProductCopy.PlanProjection.self
        let activityCopy = FormaProductCopy.PlanEditActivity.self

        let maintenance = projection.maintenanceCalories
            ?? PlanBodyBaselineMaintenanceEstimator.preliminaryMaintenanceKcal(
                formState: formState,
                activityLevel: formState.activityLevel
            )

        let trainingDays = Int(
            formState.trainingFrequencyPerWeekText.trimmingCharacters(in: .whitespacesAndNewlines)
        ) ?? ActivityTrainingDefaultsResolver().defaults(for: formState.activityLevel).trainingDaysPerWeek
        let steps = Int(
            formState.averageStepsText.trimmingCharacters(in: .whitespacesAndNewlines)
        ) ?? ActivityTrainingDefaultsResolver().defaults(for: formState.activityLevel).averageStepsPerDay

        return PlanActivityTargetPreviewState(
            maintenanceCalories: maintenance.map {
                PlanDisplayFormatter.formatKcalPerDay($0)
            },
            targetCalories: projection.targetCalories.map {
                PlanDisplayFormatter.formatKcalPerDay($0)
            },
            proteinTarget: projection.proteinTargetG.map { formatGrams($0) },
            trainingAssumption: activityCopy.trainingAssumption(days: trainingDays, steps: steps),
            isComplete: maintenance != nil || projection.targetCalories != nil
        )
    }

    private static func formatGrams(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value)) g"
            : String(format: "%.0f g", value)
    }
}
