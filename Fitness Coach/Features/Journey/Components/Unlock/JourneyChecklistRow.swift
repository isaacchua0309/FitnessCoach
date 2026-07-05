//
//  JourneyChecklistRow.swift
//  Fitness Coach
//
//  Forma — Checklist row for Journey unlock progress.
//

import SwiftUI

struct JourneyChecklistRow: View {
    let item: JourneyUnlockChecklistItem

    var body: some View {
        HStack(alignment: .top, spacing: FormaTokens.Spacing.sm) {
            statusIcon
                .font(JourneyTypography.cardSupporting.weight(.semibold))
                .foregroundStyle(statusColor)
                .frame(width: 18, alignment: .center)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(JourneyTypography.cardSupporting)
                    .foregroundStyle(titleColor)
                    .fixedSize(horizontal: false, vertical: true)

                if let progressLabel = progressLabel {
                    Text(progressLabel)
                        .font(FormaTokens.Typography.caption2)
                        .foregroundStyle(FormaTokens.Color.textTertiary)
                }
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.accessibilityLabel)
    }

    private var statusIcon: Text {
        switch item.status {
        case .completed:
            return Text("✓")
        case .inProgress:
            return Text("◐")
        case .pending:
            return Text("○")
        }
    }

    private var statusColor: Color {
        switch item.status {
        case .completed:
            return FormaTokens.Theme.primary
        case .inProgress:
            return FormaTokens.Theme.primary.opacity(0.85)
        case .pending:
            return FormaTokens.Color.textTertiary
        }
    }

    private var titleColor: Color {
        switch item.status {
        case .completed:
            return FormaTokens.Color.textSecondary
        case .inProgress, .pending:
            return FormaTokens.Color.textPrimary
        }
    }

    private var progressLabel: String? {
        guard case .inProgress(let current, let total) = item.status else { return nil }
        return "\(current) / \(total)"
    }
}

#if DEBUG
#Preview("Checklist rows") {
    let checklist = JourneyUnlockChecklistBuilder.buildChecklist(
        JourneyUnlockChecklistBuilder.Input(
            stats: JourneyPreviewData.brandNewUser.screenPresentation.weekly.stats,
            unlocks: JourneyPreviewData.brandNewUser.screenPresentation.unlocks,
            nextBestAction: JourneyPreviewData.brandNewUser.screenPresentation.nextBestAction,
            summary: JourneyPreviewData.brandNewUser.weeklyProgressSummary
        )
    )

    VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
        ForEach(checklist.items) { item in
            JourneyChecklistRow(item: item)
        }
    }
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
#endif
