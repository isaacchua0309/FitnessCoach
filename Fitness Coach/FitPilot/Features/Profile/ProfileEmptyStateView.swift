//
//  ProfileEmptyStateView.swift
//  Fitness Coach
//
//  FitPilot AI — Onboarding entry for My Plan.
//

import SwiftUI

struct ProfileEmptyStateView: View {
    let onCreateProfile: () -> Void

    var body: some View {
        VStack(spacing: FormaTokens.Spacing.md) {
            Text(FormaProductCopy.EmptyState.planTitle)
                .font(FormaTokens.Typography.sectionTitle.weight(.bold))
                .foregroundStyle(FormaTokens.Color.textPrimary)

            Text(FormaProductCopy.EmptyState.planGetStarted)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(FormaTokens.Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(FormaProductCopy.Common.getStarted, action: onCreateProfile)
                .buttonStyle(.borderedProminent)
                .tint(FormaTokens.Color.accent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FormaTokens.Color.canvas)
    }
}

#Preview {
    ProfileEmptyStateView(onCreateProfile: {})
        .preferredColorScheme(.dark)
}
