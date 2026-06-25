//
//  CoachEmptyState.swift
//  Fitness Coach
//
//  FitPilot AI — Calm empty conversation state. Commands live in the toolbar.
//

import SwiftUI

struct CoachEmptyState: View {
    var body: some View {
        VStack(alignment: .leading, spacing: CoachDesignTokens.Spacing.sm) {
            Spacer(minLength: CoachDesignTokens.Spacing.xxl)

            Text("Log meals, water, weight, and workouts from here.")
                .font(CoachDesignTokens.Typography.hint)
                .foregroundStyle(CoachDesignTokens.Color.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text("Your most-used commands appear first in the toolbar.")
                .font(CoachDesignTokens.Typography.hint)
                .foregroundStyle(CoachDesignTokens.Color.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: CoachDesignTokens.Spacing.xxl)
        }
        .padding(.horizontal, CoachDesignTokens.Layout.horizontalPadding)
    }
}

#Preview {
    CoachEmptyState()
        .background(CoachDesignTokens.Color.background)
        .preferredColorScheme(.dark)
}
