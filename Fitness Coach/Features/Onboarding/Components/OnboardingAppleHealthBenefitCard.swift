//
//  OnboardingAppleHealthBenefitCard.swift
//  Fitness Coach
//
//  Forma — Benefit row for Apple Health onboarding.
//

import SwiftUI

struct OnboardingAppleHealthBenefitCard: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: FormaTokens.Spacing.md) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(OnboardingTheme.accent)
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
                Text(title)
                    .font(FormaTokens.Typography.body.weight(.semibold))
                    .foregroundStyle(OnboardingTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(OnboardingTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(FormaTokens.Spacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous)
                .fill(FormaTokens.Color.surfaceSubtle)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle)")
    }
}

#if DEBUG
#Preview {
    OnboardingAppleHealthBenefitCard(
        icon: "figure.run",
        title: "Workout tracking",
        subtitle: "See workout days, duration, and training consistency."
    )
    .padding()
    .background(OnboardingTheme.background)
    .formaThemePreview()
}
#endif
