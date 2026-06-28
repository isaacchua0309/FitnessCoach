//
//  JourneyBeforeTodaySection.swift
//  Fitness Coach
//

import SwiftUI

struct JourneyBeforeTodaySection: View {
    let state: JourneyBeforeTodayState

    var body: some View {
        VStack(alignment: .leading, spacing: JourneyLayout.itemSpacing) {
            FormaSectionLabel(title: FormaProductCopy.Journey.BeforeToday.sectionTitle)

            FitPilotPlanCard {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.md) {
                    comparisonColumns

                    if state.showsAdaptedTargetCopy {
                        Text(FormaProductCopy.Journey.BeforeToday.adaptedTargetCopy)
                            .font(FormaTokens.Typography.caption)
                            .foregroundStyle(FormaTokens.Color.accent)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    goalRow
                }
            }
        }
    }

    private var comparisonColumns: some View {
        HStack(alignment: .top, spacing: FormaTokens.Spacing.md) {
            column(
                title: FormaProductCopy.Journey.Transformation.columnStarted,
                weightKg: state.startedWeightKg,
                maintenanceKcal: state.showsMaintenanceRow ? state.startingMaintenanceCaloriesKcal : nil,
                targetKcal: state.showsTargetRow ? state.startingTargetCaloriesKcal : nil
            )

            column(
                title: FormaProductCopy.Journey.Transformation.columnToday,
                weightKg: state.currentWeightKg,
                maintenanceKcal: state.showsMaintenanceRow ? state.currentMaintenanceCaloriesKcal : nil,
                targetKcal: state.showsTargetRow ? state.currentTargetCaloriesKcal : nil
            )
        }
    }

    private var goalRow: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
            FitPilotPlanRowDivider()

            Text(FormaProductCopy.Journey.Transformation.columnGoal)
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(FormaTokens.Color.textTertiary)

            Text(formattedWeight(state.goalWeightKg))
                .font(FormaTokens.Typography.sectionTitle.weight(.semibold))
                .foregroundStyle(FormaTokens.Color.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func column(
        title: String,
        weightKg: Double?,
        maintenanceKcal: Int?,
        targetKcal: Int?
    ) -> some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
            Text(title)
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(FormaTokens.Color.textTertiary)

            metricLine(value: formattedWeight(weightKg))

            if let maintenanceKcal {
                metricLine(
                    label: FormaProductCopy.Journey.BeforeToday.maintenanceLabel,
                    value: formattedKcal(maintenanceKcal)
                )
            }

            if let targetKcal {
                metricLine(
                    label: FormaProductCopy.Journey.BeforeToday.targetLabel,
                    value: formattedKcal(targetKcal)
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metricLine(label: String? = nil, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if let label {
                Text(label)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(FormaTokens.Color.textTertiary)
            }

            Text(value)
                .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                .foregroundStyle(FormaTokens.Color.textPrimary)
                .minimumScaleFactor(0.85)
                .lineLimit(1)
        }
    }

    private func formattedWeight(_ value: Double?) -> String {
        guard let value else { return "—" }
        return value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value))kg"
            : String(format: "%.1fkg", value)
    }

    private func formattedKcal(_ value: Int) -> String {
        PlanDisplayFormatter.formatGroupedInteger(value)
    }
}

// MARK: - Previews

#Preview("Full snapshot") {
    JourneyBeforeTodaySection(state: ProgressPreviewData.beforeTodayActive)
        .padding()
        .background(FormaTokens.Color.canvas)
        .preferredColorScheme(.dark)
}

#Preview("Weights only") {
    JourneyBeforeTodaySection(state: ProgressPreviewData.beforeTodayWeightsOnly)
        .padding()
        .background(FormaTokens.Color.canvas)
        .preferredColorScheme(.dark)
}
