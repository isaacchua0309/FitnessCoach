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
        PlanEditCard {
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                if let validationError {
                    Text(validationError)
                        .font(FormaTokens.Typography.caption)
                        .foregroundStyle(FormaPlanTokens.Color.planDanger)
                } else {
                    difficultyHeader

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
    private var difficultyHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(projection.difficultyLabel)
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(FormaPlanTokens.Color.planAccent)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background {
                    Capsule()
                        .fill(FormaPlanTokens.Color.planAccentSoft)
                }

            Text(projection.difficultyDescription)
                .font(FormaTokens.Typography.sectionSubtitle.weight(.medium))
                .foregroundStyle(FormaPlanTokens.Color.planPrimaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var paceRows: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let weekly = projection.weeklyRateKg {
                metricRow(
                    label: copy.weeklyPaceLabel,
                    value: formatKgRate(weekly, period: "/week")
                )
            }
            if let monthly = projection.monthlyRateKg {
                metricRow(
                    label: copy.monthlyPaceLabel,
                    value: formatKgRate(monthly, period: "/month")
                )
            }
            if let balance = projection.dailyDeficitOrSurplusLabel {
                metricRow(label: copy.energyBalanceLabel, value: balance)
            }
        }
    }

    private func metricRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(FormaPlanTokens.Color.planMutedText)
            Spacer()
            Text(value)
                .font(FormaTokens.Typography.caption.weight(.medium))
                .foregroundStyle(FormaPlanTokens.Color.planSecondaryText)
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
            PlanEditCard {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                    if let maintenance = projection.maintenanceCalories {
                        metricRow(
                            label: copy.maintenanceLabel,
                            value: "\(maintenance) kcal"
                        )
                    }
                    if let target = projection.targetCalories {
                        metricRow(
                            label: copy.targetCaloriesLabel,
                            value: "\(target) kcal"
                        )
                    }
                    if let protein = projection.proteinTargetG {
                        metricRow(
                            label: copy.proteinLabel,
                            value: formatGrams(protein)
                        )
                    }
                    if let carbs = projection.carbTargetG {
                        metricRow(
                            label: copy.carbsLabel,
                            value: formatGrams(carbs)
                        )
                    }
                    if let fat = projection.fatTargetG {
                        metricRow(
                            label: copy.fatLabel,
                            value: formatGrams(fat)
                        )
                    }
                    if let water = projection.waterTargetMl {
                        metricRow(
                            label: copy.waterLabel,
                            value: "\(water) ml"
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

    private func metricRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(FormaPlanTokens.Color.planMutedText)
            Spacer()
            Text(value)
                .font(FormaTokens.Typography.caption.weight(.medium))
                .foregroundStyle(FormaPlanTokens.Color.planSecondaryText)
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
        PlanEditCard {
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
