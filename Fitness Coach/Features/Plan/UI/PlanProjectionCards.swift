//
//  PlanProjectionCards.swift
//  Fitness Coach
//
//  Forma — Shared projection preview cards for Edit Plan screens.
//

import SwiftUI

// MARK: - Pace

struct PlanProjectionPaceCard: View {
    let projection: PlanProjection
    var validationError: String?
    var supplementalWarning: String?

    private let copy = FormaProductCopy.PlanProjection.self

    var body: some View {
        PlanProjectionCard {
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                if let validationError {
                    Text(validationError)
                        .font(FormaTokens.Typography.caption)
                        .foregroundStyle(FormaPlanTokens.Color.planDanger)
                } else {
                    PlanDifficultyBadge(
                        model: PlanDifficultyBadgeDisplayModel(
                            label: projection.difficultyLabel,
                            description: projection.difficultyDescription
                        )
                    )

                    if projection.hasPaceMetrics {
                        paceRows
                    }

                    if let supplementalWarning {
                        Text(supplementalWarning)
                            .font(FormaTokens.Typography.caption)
                            .foregroundStyle(FormaPlanTokens.Color.planSecondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let validationMessage = projection.validationMessage {
                        Text(validationMessage)
                            .font(FormaTokens.Typography.caption)
                            .foregroundStyle(FormaPlanTokens.Color.planMutedText)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var paceRows: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let weekly = projection.weeklyRateKg {
                PlanMetricRow(
                    label: copy.weeklyPaceLabel,
                    value: formatKgRate(weekly, period: "/week"),
                    valueWeight: .medium
                )
            }
            if let monthly = projection.monthlyRateKg {
                PlanMetricRow(
                    label: copy.monthlyPaceLabel,
                    value: formatKgRate(monthly, period: "/month"),
                    valueWeight: .medium
                )
            }
            if let balance = projection.dailyDeficitOrSurplusLabel {
                PlanMetricRow(label: copy.energyBalanceLabel, value: balance, valueWeight: .medium)
            }
        }
    }

    private func formatKgRate(_ value: Double, period: String) -> String {
        let amount = value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value)) kg"
            : String(format: "%.1f kg", value)
        return amount + period
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
                impactRow(label: copy.adherenceLabel, value: projection.adherenceEstimate)
                impactRow(label: copy.recoveryLabel, value: projection.recoveryImpact)
                impactRow(label: copy.hungerLabel, value: projection.hungerImpact)
            }
        }
    }

    private func impactRow(label: String, value: String) -> some View {
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
