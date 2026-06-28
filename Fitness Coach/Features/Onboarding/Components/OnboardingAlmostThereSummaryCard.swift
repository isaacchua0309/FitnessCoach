//
//  OnboardingAlmostThereSummaryCard.swift
//  Fitness Coach
//
//  Forma — Summary card for the almost-there onboarding milestone.
//

import SwiftUI

struct OnboardingAlmostThereSummaryCard: View {
    let headline: String
    let supportingCopy: String

    var body: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
            Text(headline)
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(OnboardingTheme.primaryText)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)

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
        .accessibilityLabel("\(headline) \(supportingCopy)")
    }
}

#if DEBUG
#Preview {
    OnboardingAlmostThereSummaryCard(
        headline: FormaProductCopy.Onboarding.Flow.AlmostThere.summaryHeadline,
        supportingCopy: FormaProductCopy.Onboarding.Flow.AlmostThere.summarySupporting
    )
    .padding()
    .background(OnboardingTheme.background)
    .preferredColorScheme(.dark)
}
#endif
