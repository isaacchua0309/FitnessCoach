//
//  JourneyEmptyStateView.swift
//  Fitness Coach
//
//  FitPilot AI — Compact empty state when profile is missing.
//

import SwiftUI

struct JourneyEmptyStateView: View {
    let onRefresh: () -> Void

    var body: some View {
        VStack(spacing: FormaTokens.Spacing.sm + 2) {
            Text(FormaProductCopy.EmptyState.journeyTitle)
                .font(FormaTokens.Typography.sectionTitle.weight(.semibold))
                .foregroundStyle(FormaTokens.Color.textPrimary)
                .multilineTextAlignment(.center)

            Text(FormaProductCopy.EmptyState.journeyBody)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(FormaTokens.Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(FormaProductCopy.Common.refresh, action: onRefresh)
                .buttonStyle(.bordered)
                .tint(FormaTokens.Color.accent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(FormaTokens.Color.canvas)
    }
}

#Preview {
    JourneyEmptyStateView {}
        .formaThemePreview()
}
