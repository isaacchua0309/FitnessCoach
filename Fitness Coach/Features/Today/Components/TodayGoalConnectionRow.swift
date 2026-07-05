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

    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: handleTap) {
            MainTabCard(style: .surfaceSubtle, compact: true) {
                HStack(alignment: .center, spacing: FormaTokens.Spacing.sm) {
                    Image(systemName: "arrow.up.forward")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.accent.opacity(0.85))
                        .accessibilityHidden(true)

                    Text(connection.message)
                        .font(FormaTokens.Typography.caption)
                        .foregroundStyle(theme.secondaryText)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                        .minimumScaleFactor(0.9)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(theme.tertiaryText)
                        .accessibilityHidden(true)
                }
            }
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

#if DEBUG
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
    .padding(.horizontal, FormaMainTabLayout.horizontalPadding)
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
#endif
