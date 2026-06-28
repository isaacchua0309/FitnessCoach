//
//  JourneyMonthlyRecapSection.swift
//  Fitness Coach
//

import SwiftUI

struct JourneyMonthlyRecapSection: View {
    let state: JourneyMonthlyRecapState

    var body: some View {
        VStack(alignment: .leading, spacing: JourneyLayout.itemSpacing) {
            FormaSectionLabel(title: state.sectionTitle)

            FitPilotPlanCard {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                    if let buildingMessage = state.buildingMessage {
                        Text(buildingMessage)
                            .font(FormaTokens.Typography.sectionSubtitle)
                            .foregroundStyle(FormaTokens.Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if !state.summaryCopy.isEmpty {
                        Text(state.summaryCopy)
                            .font(FormaTokens.Typography.sectionSubtitle)
                            .foregroundStyle(
                                state.isComplete
                                    ? FormaTokens.Color.textSecondary
                                    : FormaTokens.Color.textTertiary
                            )
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if !state.rows.isEmpty {
                        if state.isComplete || state.loggedDays > 0 {
                            FitPilotPlanRowDivider()
                        }

                        ForEach(Array(state.rows.enumerated()), id: \.element.id) { index, row in
                            metricRow(row)
                            if index < state.rows.count - 1 {
                                FitPilotPlanRowDivider()
                            }
                        }
                    }
                }
            }
        }
    }

    private func metricRow(_ row: JourneyMonthlyRecapMetricRow) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: FormaTokens.Spacing.sm) {
            Text(row.title)
                .font(FormaTokens.Typography.sectionSubtitle.weight(.medium))
                .foregroundStyle(FormaTokens.Color.textPrimary)

            Spacer(minLength: FormaTokens.Spacing.xs)

            Text(row.value)
                .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                .foregroundStyle(FormaTokens.Color.textSecondary)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, FormaTokens.Spacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(row.title), \(row.value)")
    }
}

#if DEBUG
#Preview("Monthly recap") {
    ScrollView {
        JourneyMonthlyRecapSection(state: ProgressPreviewData.monthlyRecapActive)
            .padding()
    }
    .background(FormaTokens.Color.canvas)
    .preferredColorScheme(.dark)
}
#endif
