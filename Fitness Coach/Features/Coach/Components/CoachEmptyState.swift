//
//  CoachEmptyState.swift
//  Fitness Coach
//
//  FitPilot AI — Calm empty conversation state with tappable starters.
//

import SwiftUI

struct CoachEmptyState: View {
    let isDisabled: Bool
    let onStarterTap: (CoachStarterPrompt) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: CoachDesignTokens.Spacing.md) {
            Spacer(minLength: CoachDesignTokens.Spacing.xl)

            Text(FormaProductCopy.Coach.emptyIntro)
                .font(CoachDesignTokens.Typography.hint)
                .foregroundStyle(CoachDesignTokens.Color.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            CoachStarterChips(isDisabled: isDisabled, onTap: onStarterTap)

            Spacer(minLength: CoachDesignTokens.Spacing.xl)
        }
        .padding(.horizontal, CoachDesignTokens.Layout.horizontalPadding)
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    CoachEmptyState(isDisabled: false) { _ in }
        .background(CoachDesignTokens.Color.background)
        .preferredColorScheme(.dark)
}
