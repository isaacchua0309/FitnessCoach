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
        VStack(spacing: FormaTokens.Spacing.md) {
            JourneyEyebrowLabel(title: FormaProductCopy.Journey.Header.title)

            Text(FormaProductCopy.Journey.StartingEmptyState.title)
                .font(JourneyTypography.cardHeadline)
                .foregroundStyle(FormaTokens.Color.textPrimary)
                .multilineTextAlignment(.center)

            Text(FormaProductCopy.Journey.StartingEmptyState.body)
                .font(JourneyTypography.cardSupporting)
                .foregroundStyle(FormaTokens.Color.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(4)
                .padding(.horizontal, FormaTokens.Spacing.sm)

            Button(FormaProductCopy.Journey.StartingEmptyState.action, action: onGoToToday)
                .buttonStyle(.borderedProminent)
                .tint(FormaTokens.Theme.primary)
                .padding(.top, FormaTokens.Spacing.xs)
        }
        .frame(maxWidth: FormaTokens.Layout.maxContentWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, JourneyLayout.horizontalPadding)
        .padding(
            .bottom,
            JourneyLayout.scrollBottomInset(
                bottomSafeArea: FormaTokens.Layout.homeIndicatorSafeAreaEstimate,
                dynamicTypeSize: .large
            )
        )
        .background(FormaTokens.Color.canvas)
        .accessibilityIdentifier("journey-empty-state")
    }
}

#Preview {
    JourneyEmptyStateView(onGoToToday: {})
        .formaThemePreview()
}
