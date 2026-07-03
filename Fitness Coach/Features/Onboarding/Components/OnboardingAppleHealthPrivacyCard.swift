//
//  OnboardingAppleHealthPrivacyCard.swift
//  Fitness Coach
//
//  Forma — Privacy reassurance for Apple Health onboarding.
//

import SwiftUI

struct OnboardingAppleHealthPrivacyCard: View {
    let title: String
    let bodyCopy: String

    var body: some View {
        HStack(alignment: .top, spacing: FormaTokens.Spacing.sm) {
            Image(systemName: "lock.shield")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(OnboardingTheme.accent)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                    .foregroundStyle(OnboardingTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text(bodyCopy)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(OnboardingTheme.secondaryText)
                    .lineSpacing(OnboardingUnifiedChromeTypography.subtitleLineSpacing)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onboardingUnifiedStepCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(bodyCopy)")
    }
}

#if DEBUG
#Preview {
    OnboardingAppleHealthPrivacyCard(
        title: FormaProductCopy.Onboarding.Flow.AppleHealth.privacyTitle,
        bodyCopy: FormaProductCopy.Onboarding.Flow.AppleHealth.privacyBody
    )
    .padding()
    .background(OnboardingTheme.background)
    .formaThemePreview()
}
#endif
