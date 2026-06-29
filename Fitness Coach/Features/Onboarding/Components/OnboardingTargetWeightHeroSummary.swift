//
//  OnboardingTargetWeightHeroSummary.swift
//  Fitness Coach
//
//  Forma — Hero goal summary for target weight onboarding.
//

import SwiftUI

struct OnboardingTargetWeightHeroSummary: View {
    let valueLine: String
    let journeyLine: String?
    var deltaLine: String?
    var isCompact: Bool = false

    var body: some View {
        VStack(spacing: isCompact ? FormaTokens.Spacing.xs : FormaTokens.Spacing.sm) {
            Text(valueLine)
                .font(
                    isCompact
                        ? .system(.title, design: .rounded).weight(.bold)
                        : .system(.largeTitle, design: .rounded).weight(.bold)
                )
                .foregroundStyle(OnboardingTheme.primaryText)
                .minimumScaleFactor(0.72)
                .lineLimit(1)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .contentTransition(.numericText())
                .accessibilityAddTraits(.isHeader)

            if let journeyLine {
                Text(journeyLine)
                    .font(isCompact ? FormaTokens.Typography.caption.weight(.medium) : FormaTokens.Typography.bodyMedium)
                    .foregroundStyle(OnboardingTheme.secondaryText)
                    .minimumScaleFactor(0.85)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .contentTransition(.numericText())
            }

            if let deltaLine {
                Text(deltaLine)
                    .font(FormaTokens.Typography.caption.weight(.semibold))
                    .foregroundStyle(OnboardingTheme.primaryText)
                    .minimumScaleFactor(0.85)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .contentTransition(.numericText())
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        [valueLine, journeyLine, deltaLine]
            .compactMap { $0 }
            .joined(separator: ". ")
    }
}

#if DEBUG
#Preview("Target Weight Hero — Loss") {
    OnboardingTargetWeightHeroSummary(
        valueLine: "85.3 kg",
        journeyLine: "Current 90.0 kg → Goal 85.3 kg",
        deltaLine: "Lose 4.7 kg"
    )
    .padding()
    .background(OnboardingTheme.background)
    .formaThemePreview()
}
#endif
