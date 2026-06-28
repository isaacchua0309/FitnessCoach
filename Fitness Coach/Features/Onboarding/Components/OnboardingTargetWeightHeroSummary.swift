//
//  OnboardingTargetWeightHeroSummary.swift
//  Fitness Coach
//
//  Forma — Hero goal summary for target weight onboarding.
//

import SwiftUI

struct OnboardingTargetWeightHeroSummary: View {
    let headline: String
    let journeyLine: String?

    var body: some View {
        VStack(spacing: FormaTokens.Spacing.sm) {
            Text(headline)
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .foregroundStyle(OnboardingTheme.primaryText)
                .minimumScaleFactor(0.82)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.2), value: headline)
                .accessibilityAddTraits(.isHeader)

            if let journeyLine {
                Text(journeyLine)
                    .font(FormaTokens.Typography.bodyMedium)
                    .foregroundStyle(OnboardingTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.2), value: journeyLine)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        if let journeyLine {
            return "\(headline). \(journeyLine)"
        }
        return headline
    }
}

#if DEBUG
#Preview("Target Weight Hero — Loss") {
    OnboardingTargetWeightHeroSummary(
        headline: "Target 85.3 kg",
        journeyLine: "Current 90.0 kg → Goal 85.3 kg"
    )
    .padding()
    .background(OnboardingTheme.background)
    .formaThemePreview()
}
#endif
