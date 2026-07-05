//
//  JourneyInsightLockedState.swift
//  Fitness Coach
//
//  Forma — Compact locked insight presentation for Journey sections.
//

import SwiftUI

struct JourneyInsightLockedStateView: View {
    let state: JourneyInsightLockedState

    var body: some View {
        if state.isCompact {
            compactBody
        } else {
            standardBody
        }
    }

    private var compactBody: some View {
        VStack(alignment: .leading, spacing: WeeklyProgressCardSupport.blockSpacing) {
            Text(state.headline)
                .font(WeeklyProgressCardSupport.blockTitleFont)
                .foregroundStyle(FormaTokens.Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if let detail = state.detail, !detail.isEmpty {
                Text(detail)
                    .font(WeeklyProgressCardSupport.supportingFont)
                    .foregroundStyle(FormaTokens.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let progressLabel = state.progressLabel, !progressLabel.isEmpty {
                Text(progressLabel)
                    .font(FormaTokens.Typography.caption2.weight(.medium))
                    .foregroundStyle(FormaTokens.Theme.primary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(state.accessibilityLabel)
    }

    private var standardBody: some View {
        JourneyCard(elevation: .quiet) {
            compactBody
        }
    }
}

#if DEBUG
#Preview("Weight trend locked") {
    JourneyInsightLockedStateView(state: JourneyUnlockChecklistBuilder.weightTrendLockedState())
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}
#endif
