//
//  JourneyWorkoutHistoryRow.swift
//  Fitness Coach
//
//  Forma — Single workout row for Journey Health Intelligence history.
//

import SwiftUI

struct JourneyWorkoutHistoryRow: View {
    let item: JourneyWorkoutHistoryItemState
    var showsDateLabel: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: JourneyLayout.compactSpacing) {
            if showsDateLabel {
                Text(item.dateLabel)
                    .font(FormaTokens.Typography.caption2)
                    .foregroundStyle(FormaTokens.Color.textTertiary)
            }

            Text(item.workoutTitle)
                .font(JourneyTypography.cardHeadline)
                .foregroundStyle(FormaTokens.Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            metadataRow
        }
        .padding(.vertical, JourneyLayout.compactSpacing)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.accessibilityLabel)
    }

    @ViewBuilder
    private var metadataRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: FormaTokens.Spacing.sm) {
            Text(item.durationLabel)
                .font(JourneyTypography.cardSupporting.weight(.medium))
                .foregroundStyle(FormaTokens.Color.textSecondary)

            if let caloriesLabel = item.caloriesLabel {
                metadataBadge(caloriesLabel)
            }

            if let demandLabel = item.demandLabel {
                metadataBadge(demandLabel)
            }

            if let intensityLabel = item.intensityLabel {
                metadataBadge(intensityLabel)
            }

            Spacer(minLength: 0)
        }
    }

    private func metadataBadge(_ text: String) -> some View {
        Text(text)
            .font(FormaTokens.Typography.caption2.weight(.medium))
            .foregroundStyle(FormaTokens.Theme.primary)
            .padding(.horizontal, FormaTokens.Spacing.xs)
            .padding(.vertical, 2)
            .background(
                Capsule(style: .continuous)
                    .fill(FormaTokens.Theme.softBackground.opacity(0.72))
            )
    }
}

// MARK: - Previews

#Preview("Single row") {
    JourneyWorkoutHistoryRow(
        item: JourneyHealthIntelligencePreviewData.strongWeek.workoutHistory.items.first!,
        showsDateLabel: true
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Row without date") {
    JourneyWorkoutHistoryRow(
        item: JourneyHealthIntelligencePreviewData.strongWeek.workoutHistory.items.first!
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
