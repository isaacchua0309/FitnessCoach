//
//  OnboardingGoalCard.swift
//  Fitness Coach
//
//  Forma — Intent label + metric highlight for goal-focused onboarding screens.
//

import SwiftUI

struct OnboardingGoalCard: View {
    let intentLabel: String
    let metric: String
    var showsStabilityBand: Bool = false

    var body: some View {
        VStack(spacing: FormaTokens.Spacing.md) {
            Text(intentLabel)
                .font(OnboardingMarketingTypography.goalIntent)
                .foregroundStyle(OnboardingTheme.accent)
                .textCase(.uppercase)
                .tracking(1.2)
                .accessibilityHidden(true)

            OnboardingMetricHighlight(
                value: metric,
                showsStabilityBand: showsStabilityBand
            )
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(intentLabel), \(metric)")
    }
}

#if DEBUG
#Preview {
    OnboardingGoalCard(intentLabel: "Maintain", metric: "70 kg", showsStabilityBand: true)
        .padding()
        .background(OnboardingTheme.background)
        .formaThemePreview()
}
#endif
