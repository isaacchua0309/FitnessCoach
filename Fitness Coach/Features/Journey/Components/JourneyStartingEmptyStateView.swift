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
        FormaPlanCard {
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                Text(FormaProductCopy.Journey.StartingEmptyState.title)
                    .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                    .foregroundStyle(FormaTokens.Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(FormaProductCopy.Journey.StartingEmptyState.body)
                    .font(FormaTokens.Typography.sectionSubtitle)
                    .foregroundStyle(FormaTokens.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button(FormaProductCopy.Journey.StartingEmptyState.action, action: onGoToToday)
                    .buttonStyle(.borderedProminent)
                    .tint(FormaTokens.Theme.primary)
                    .padding(.top, FormaTokens.Spacing.xs)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
