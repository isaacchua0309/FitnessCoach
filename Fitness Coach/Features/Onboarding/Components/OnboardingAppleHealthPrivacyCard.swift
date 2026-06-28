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
                .font(.body.weight(.semibold))
                .foregroundStyle(OnboardingTheme.accent)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
                Text(title)
                    .font(FormaTokens.Typography.body.weight(.semibold))
                    .foregroundStyle(OnboardingTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text(bodyCopy)
                    .font(FormaTokens.Typography.body)
                    .foregroundStyle(OnboardingTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
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
