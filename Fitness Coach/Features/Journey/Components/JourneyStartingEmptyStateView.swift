//
//  JourneyStartingEmptyStateView.swift
//  Fitness Coach
//
//  Forma — Intentional empty state when Journey has no milestones or story yet.
//

import SwiftUI

struct JourneyStartingEmptyStateView: View {
    let onGoToToday: () -> Void

    var body: some View {
        JourneyCard(elevation: .quiet) {
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                Text(FormaProductCopy.Journey.StartingEmptyState.title)
                    .font(JourneyTypography.cardHeadline)
                    .foregroundStyle(FormaTokens.Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(FormaProductCopy.Journey.StartingEmptyState.body)
                    .font(JourneyTypography.cardSupporting)
                    .foregroundStyle(FormaTokens.Color.textSecondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                Button(FormaProductCopy.Journey.StartingEmptyState.action, action: onGoToToday)
                    .buttonStyle(.borderedProminent)
                    .tint(FormaTokens.Theme.primary)
                    .controlSize(.regular)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, JourneyLayout.compactSpacing)
            }
        }
        .accessibilityIdentifier("journey-starting-empty-state")
    }
}

#Preview {
    JourneyStartingEmptyStateView(onGoToToday: {})
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}

#Preview("Dark mode") {
    JourneyStartingEmptyStateView(onGoToToday: {})
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
        .preferredColorScheme(.dark)
}
