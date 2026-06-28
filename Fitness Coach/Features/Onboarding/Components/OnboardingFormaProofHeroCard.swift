//
//  OnboardingFormaProofHeroCard.swift
//  Fitness Coach
//
//  Forma — Hero metric card for forma proof onboarding.
//

import SwiftUI

struct OnboardingFormaProofHeroCard: View {
    let heroMetric: String
    let journeyLine: String?
    let supportingCopy: String

    var body: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.md) {
            Text(heroMetric)
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(OnboardingTheme.primaryText)
                .minimumScaleFactor(0.8)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            if let journeyLine {
                Text(journeyLine)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(OnboardingTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(supportingCopy)
                .font(FormaTokens.Typography.body)
                .foregroundStyle(OnboardingTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(FormaTokens.Spacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous)
                .fill(FormaTokens.Color.surfaceSubtle)
        )
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview {
    OnboardingFormaProofHeroCard(
        heroMetric: "Lose 3.5 kg",
        journeyLine: "70 kg → 66.5 kg",
        supportingCopy: FormaProductCopy.Onboarding.Flow.FormaProof.Loss.heroSupporting
    )
    .padding()
    .background(OnboardingTheme.background)
    .formaThemePreview()
}
#endif
