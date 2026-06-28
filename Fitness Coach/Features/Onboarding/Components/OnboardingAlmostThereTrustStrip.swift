//
//  OnboardingAlmostThereTrustStrip.swift
//  Fitness Coach
//
//  Forma — Trust reassurance for the almost-there onboarding milestone.
//

import SwiftUI

struct OnboardingAlmostThereTrustStrip: View {
    let copy: String

    var body: some View {
        HStack(spacing: FormaTokens.Spacing.sm) {
            Image(systemName: "leaf.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(OnboardingTheme.accent)
                .accessibilityHidden(true)

            Text(copy)
                .font(FormaTokens.Typography.body.weight(.medium))
                .foregroundStyle(OnboardingTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, FormaTokens.Spacing.cardPadding)
        .padding(.vertical, FormaTokens.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous)
                .fill(FormaTokens.Color.surfaceSubtle.opacity(0.72))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(copy)
    }
}

#if DEBUG
#Preview {
    OnboardingAlmostThereTrustStrip(
        copy: FormaProductCopy.Onboarding.Flow.AlmostThere.trustStrip
    )
    .padding()
    .background(OnboardingTheme.background)
    .formaThemePreview()
}
#endif
