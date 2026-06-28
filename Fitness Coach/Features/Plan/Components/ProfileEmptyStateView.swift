//
//  ProfileEmptyStateView.swift
//  Fitness Coach
//
//  FitPilot AI — Empty Plan state when no profile exists locally.
//

import SwiftUI

struct ProfileEmptyStateView: View {
    let onCreateProfile: () -> Void

    var body: some View {
        VStack(spacing: FormaTokens.Spacing.md) {
            Text(FormaProductCopy.EmptyState.planTitle)
                .font(FormaTokens.Typography.sectionTitle.weight(.bold))
                .foregroundStyle(FormaTokens.Color.textPrimary)
                .multilineTextAlignment(.center)

            Text(FormaProductCopy.EmptyState.planGetStarted)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(FormaTokens.Color.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal)

            Button(FormaProductCopy.Common.getStarted, action: onCreateProfile)
                .buttonStyle(.borderedProminent)
                .tint(FormaTokens.Color.accent)
                .accessibilityHint(FormaProductCopy.EmptyState.planGetStartedAccessibilityHint)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FormaTokens.Color.canvas)
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    ProfileEmptyStateView(onCreateProfile: {})
        .preferredColorScheme(.dark)
}

#Preview("Large Dynamic Type") {
    ProfileEmptyStateView(onCreateProfile: {})
        .preferredColorScheme(.dark)
        .dynamicTypeSize(.accessibility3)
}
