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
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(state.accessibilitySummary)
        }
    }

    private var comparisonColumns: some View {
        HStack(alignment: .top, spacing: FormaTokens.Spacing.md) {
            column(
                title: FormaProductCopy.Journey.Transformation.columnStarted,
                weight: state.startedWeightCopy,
                maintenance: state.showsMaintenanceRow ? state.startingMaintenanceCopy : nil,
                target: state.showsTargetRow ? state.startingTargetCopy : nil
            )

            column(
                title: FormaProductCopy.Journey.Transformation.columnToday,
                weight: state.currentWeightCopy,
                maintenance: state.showsMaintenanceRow ? state.currentMaintenanceCopy : nil,
                target: state.showsTargetRow ? state.currentTargetCopy : nil
            )
        }
    }

    private var goalRow: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
            FitPilotPlanRowDivider()

            Text(FormaProductCopy.Journey.Transformation.columnGoal)
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(FormaTokens.Color.textTertiary)

            Text(state.goalWeightCopy)
                .font(FormaTokens.Typography.sectionTitle.weight(.semibold))
                .foregroundStyle(FormaTokens.Color.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func column(
        title: String,
        weight: String,
        maintenance: String?,
        target: String?
    ) -> some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
            Text(title)
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(FormaTokens.Color.textTertiary)

            metricLine(value: weight)

            if let maintenance {
                metricLine(
                    label: FormaProductCopy.Journey.BeforeToday.maintenanceLabel,
                    value: maintenance
                )
            }

            if let target {
                metricLine(
                    label: FormaProductCopy.Journey.BeforeToday.targetLabel,
                    value: target
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
}

// MARK: - Previews

#Preview("Full snapshot") {
    JourneyBeforeTodaySection(state: ProgressPreviewData.beforeTodayActive)
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}

#Preview("Weights only") {
    JourneyBeforeTodaySection(state: ProgressPreviewData.beforeTodayWeightsOnly)
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}
