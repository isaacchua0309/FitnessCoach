//
//  PlanProjectionCards.swift
//  Fitness Coach
//
//  Forma — Shared projection preview cards for Edit Plan screens.
//

import SwiftUI

// MARK: - Impact row

struct PlanProjectionImpactRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(FormaPlanTokens.Color.planMutedText)
            Text(value)
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(FormaPlanTokens.Color.planSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Energy & targets

struct PlanProjectionEnergyCard: View {
    let projection: PlanProjection

    private let copy = FormaProductCopy.PlanProjection.self

    var body: some View {
        if projection.hasEnergyTargets || projection.hasMacroTargets {
            PlanProjectionCard {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                    if let maintenance = projection.maintenanceCalories {
                        PlanMetricRow(
                            label: copy.maintenanceLabel,
                            value: "\(maintenance) kcal",
                            valueWeight: .medium
                        )
                    }
                    if let target = projection.targetCalories {
                        PlanMetricRow(
                            label: copy.targetCaloriesLabel,
                            value: "\(target) kcal",
                            valueWeight: .medium
                        )
                    }
                    if let protein = projection.proteinTargetG {
                        PlanMetricRow(
                            label: copy.proteinLabel,
                            value: formatGrams(protein),
                            valueWeight: .medium
                        )
                    }
                    if let carbs = projection.carbTargetG {
                        PlanMetricRow(
                            label: copy.carbsLabel,
                            value: formatGrams(carbs),
                            valueWeight: .medium
                        )
                    }
                    if let fat = projection.fatTargetG {
                        PlanMetricRow(
                            label: copy.fatLabel,
                            value: formatGrams(fat),
                            valueWeight: .medium
                        )
                    }
                    if let water = projection.waterTargetMl {
                        PlanMetricRow(
                            label: copy.waterLabel,
                            value: "\(water) ml",
                            valueWeight: .medium
                        )
                    }
                    if let validationMessage = projection.validationMessage,
                       !projection.isCalculationComplete {
                        Text(validationMessage)
                            .font(FormaTokens.Typography.caption)
                            .foregroundStyle(FormaPlanTokens.Color.planMutedText)
                    }
                }
            }
        }
    }

    private func formatGrams(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value)) g"
            : String(format: "%.0f g", value)
    }
}

// MARK: - Impact

struct PlanProjectionImpactCard: View {
    let projection: PlanProjection

    private let copy = FormaProductCopy.PlanProjection.self

    var body: some View {
        PlanProjectionCard {
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                PlanProjectionImpactRow(label: copy.adherenceLabel, value: projection.adherenceEstimate)
                PlanProjectionImpactRow(label: copy.recoveryLabel, value: projection.recoveryImpact)
                PlanProjectionImpactRow(label: copy.hungerLabel, value: projection.hungerImpact)
            }
        }
    }
}
