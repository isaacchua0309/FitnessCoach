//
//  TodayGoalConnectionRow.swift
//  Fitness Coach
//
//  Forma — Compact Today → long-term goal connection row.
//

import SwiftUI

struct TodayGoalConnectionRow: View {
    let connection: TodayGoalConnectionState
    let onOpenJourney: () -> Void
    let onOpenPlan: () -> Void
    var onTapped: ((TodayGoalConnectionDestination) -> Void)?

    var body: some View {
        Button(action: handleTap) {
            HStack(alignment: .center, spacing: FormaTokens.Spacing.sm) {
                Image(systemName: "arrow.up.forward")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(FormaTokens.Color.accent.opacity(0.85))
                    .accessibilityHidden(true)

                Text(connection.message)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(FormaTokens.Color.textSecondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(FormaTokens.Color.textTertiary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, FormaTokens.Spacing.md)
            .padding(.vertical, FormaTokens.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: FormaCardChrome.cornerRadius, style: .continuous)
                    .fill(FormaTokens.Color.surfaceSubtle)
                    .overlay {
                        RoundedRectangle(
                            cornerRadius: FormaCardChrome.cornerRadius,
                            style: .continuous
                        )
                        .stroke(FormaTokens.Color.border.opacity(0.45), lineWidth: 0.5)
                    }
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(connection.accessibilityLabel)
        .accessibilityHint(connection.accessibilityHint)
        .accessibilityAddTraits(.isButton)
    }

    private func handleTap() {
        onTapped?(connection.destination)
        switch connection.destination {
        case .journey:
            onOpenJourney()
        case .plan:
            onOpenPlan()
        }
    }
}

#Preview("Lose weight") {
    TodayGoalConnectionRow(
        connection: TodayGoalConnectionState(
            message: "12.4kg to your goal.",
            destination: .journey,
            accessibilityLabel: "Long-term goal. 12.4kg to your goal.",
            accessibilityHint: "Opens Journey"
        ),
        onOpenJourney: {},
        onOpenPlan: {}
    )
    .padding(.horizontal, TodayLayout.horizontalPadding)
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Maintain") {
    TodayGoalConnectionRow(
        connection: TodayGoalConnectionState(
            message: FormaProductCopy.Today.GoalConnection.maintainProgress,
            destination: .journey,
            accessibilityLabel: "Long-term goal. Stay consistent today to protect your weekly progress.",
            accessibilityHint: "Opens Journey"
        ),
        onOpenJourney: {},
        onOpenPlan: {}
    )
    .padding(.horizontal, TodayLayout.horizontalPadding)
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
