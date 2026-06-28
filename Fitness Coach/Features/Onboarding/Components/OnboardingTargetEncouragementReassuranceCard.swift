//
//  OnboardingTargetEncouragementReassuranceCard.swift
//  Fitness Coach
//
//  Forma — Reassurance card for target encouragement onboarding.
//

import SwiftUI

struct OnboardingTargetEncouragementReassuranceCard: View {
    let title: String
    let bodyCopy: String

    var body: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
            Text(title)
                .font(FormaTokens.Typography.body.weight(.semibold))
                .foregroundStyle(OnboardingTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text(bodyCopy)
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
        .accessibilityLabel("\(title). \(bodyCopy)")
    }
}

#if DEBUG
#Preview("Target Encouragement Reassurance") {
    OnboardingTargetEncouragementReassuranceCard(
        title: FormaProductCopy.Onboarding.Flow.TargetEncouragement.reassuranceTitle,
        bodyCopy: FormaProductCopy.Onboarding.Flow.TargetEncouragement.reassuranceBody
    )
    .padding()
    .background(OnboardingTheme.background)
    .formaThemePreview()
}
#endif
