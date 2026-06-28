//
//  OnboardingAlmostThereTrustStrip.swift
//  Fitness Coach
//
//  Forma — Trust reassurance for the almost-there onboarding milestone.
//

import SwiftUI

enum OnboardingAlmostThereTrustStripStyle {
    case compact
    case card
}

struct OnboardingAlmostThereTrustStrip: View {
    let copy: String
    var style: OnboardingAlmostThereTrustStripStyle = .card

    var body: some View {
        switch style {
        case .compact:
            compactBody
        case .card:
            cardBody
        }
    }

    private var compactBody: some View {
        HStack(spacing: FormaTokens.Spacing.xs) {
            Image(systemName: "leaf.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(OnboardingTheme.accent)
                .accessibilityHidden(true)

            Text(copy)
                .font(FormaTokens.Typography.caption.weight(.medium))
                .foregroundStyle(OnboardingTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(copy)
    }

    private var cardBody: some View {
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
#Preview("Compact") {
    OnboardingAlmostThereTrustStrip(
        copy: FormaProductCopy.Onboarding.Flow.AlmostThere.trustStrip,
        style: .compact
    )
    .padding()
    .background(OnboardingTheme.background)
    .formaThemePreview()
}

#Preview("Card") {
    OnboardingAlmostThereTrustStrip(
        copy: FormaProductCopy.Onboarding.Flow.AlmostThere.trustStrip,
        style: .card
    )
    .padding()
    .background(OnboardingTheme.background)
    .formaThemePreview()
}
#endif
