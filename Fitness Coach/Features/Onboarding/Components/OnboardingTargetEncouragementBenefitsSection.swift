//
//  OnboardingTargetEncouragementBenefitsSection.swift
//  Fitness Coach
//
//  Forma — Benefit rows for target encouragement onboarding.
//

import SwiftUI

struct OnboardingTargetEncouragementBenefitsSection: View {
    let benefits: [OnboardingFeatureBullet]

    var body: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.md) {
            ForEach(benefits) { bullet in
                OnboardingFeatureBulletRow(bullet: bullet)
            }
        }
        .padding(FormaTokens.Spacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous)
                .fill(FormaTokens.Color.surfaceSubtle)
        )
        .accessibilityElement(children: .contain)
    }
}

#if DEBUG
#Preview("Target Encouragement Benefits") {
    OnboardingTargetEncouragementBenefitsSection(
        benefits: FormaProductCopy.Onboarding.Flow.TargetEncouragement.benefits.map { bullet in
            OnboardingFeatureBullet(
                icon: bullet.icon,
                title: bullet.title,
                subtitle: bullet.subtitle
            )
        }
    )
    .padding()
    .background(OnboardingTheme.background)
    .preferredColorScheme(.dark)
}
#endif
