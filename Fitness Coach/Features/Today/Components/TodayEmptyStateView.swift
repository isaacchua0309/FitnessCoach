//
//  TodayEmptyStateView.swift
//  Fitness Coach
//
//  FitPilot AI — Empty state before profile/onboarding exists.
//

import SwiftUI

struct TodayEmptyStateView: View {
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: FormaTokens.Spacing.md) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 44))
                .foregroundStyle(FormaTokens.Color.textTertiary)

            Text(FormaProductCopy.EmptyState.todayTitle)
                .font(FormaTokens.Typography.sectionTitle.weight(.bold))
                .foregroundStyle(FormaTokens.Color.textPrimary)

            Text(FormaProductCopy.EmptyState.todayProfileRequired)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(FormaTokens.Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(FormaProductCopy.Common.tryAgain, action: onRetry)
                .buttonStyle(.borderedProminent)
                .tint(FormaTokens.Color.accent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(FormaTokens.Color.canvas)
    }
}

#Preview {
    TodayEmptyStateView {}
        .preferredColorScheme(.dark)
}
