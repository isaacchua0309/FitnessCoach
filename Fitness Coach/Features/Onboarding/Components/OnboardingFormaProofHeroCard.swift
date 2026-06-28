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
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
            Text(heroMetric)
                .font(.system(.title, design: .rounded).weight(.bold))
                .foregroundStyle(OnboardingTheme.primaryText)
                .minimumScaleFactor(0.8)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            if let journeyLine {
                Text(journeyLine)
                    .font(FormaTokens.Typography.sectionSubtitle.weight(.medium))
                    .foregroundStyle(OnboardingTheme.secondaryText)
                    .minimumScaleFactor(0.85)
                    .lineLimit(1)
            }

            Text(supportingCopy)
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(OnboardingTheme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(OnboardingLayout.compactCardPadding)
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
        heroMetric: "Lose toward 66.5 kg",
        journeyLine: "70 kg → 66.5 kg",
        supportingCopy: FormaProductCopy.Onboarding.Flow.FormaProof.Loss.heroSupporting
    )
    .padding()
    .background(OnboardingTheme.background)
    .formaThemePreview()
}
#endif
