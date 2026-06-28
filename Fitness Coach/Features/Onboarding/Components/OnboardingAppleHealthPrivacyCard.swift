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
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(OnboardingLayout.compactCardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous)
                .fill(FormaTokens.Color.surfaceSubtle.opacity(0.72))
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
