//
//  JourneyEmptyStateView.swift
//  Fitness Coach
//
//  FitPilot AI — Compact empty state when profile is missing.
//

import SwiftUI

struct JourneyEmptyStateView: View {
    let onGoToToday: () -> Void

    var body: some View {
        VStack(spacing: FormaTokens.Spacing.sm + 2) {
            Text(FormaProductCopy.Journey.StartingEmptyState.title)
                .font(FormaTokens.Typography.sectionTitle.weight(.semibold))
                .foregroundStyle(FormaTokens.Color.textPrimary)
                .multilineTextAlignment(.center)

            Text(FormaProductCopy.Journey.StartingEmptyState.body)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(FormaTokens.Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(FormaProductCopy.Journey.StartingEmptyState.action, action: onGoToToday)
                .buttonStyle(.borderedProminent)
                .tint(FormaTokens.Theme.primary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(FormaTokens.Color.canvas)
        .accessibilityIdentifier("journey-empty-state")
    }
}

#Preview {
    JourneyEmptyStateView(onGoToToday: {})
        .formaThemePreview()
}
