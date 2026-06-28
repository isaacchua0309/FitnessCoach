//
//  OnboardingHeroSection.swift
//  Fitness Coach
//
//  Forma — Headline and supporting copy for onboarding marketing screens.
//

import SwiftUI

struct OnboardingHeroSection: View {
    enum HeadlineStyle {
        case screen
        case vision
    }

    let headline: String
    var supporting: String? = nil
    var headlineStyle: HeadlineStyle = .screen
    var alignment: HorizontalAlignment = .center

    var body: some View {
        VStack(alignment: alignment, spacing: FormaTokens.Spacing.md) {
            Text(headline)
                .font(headlineFont)
                .foregroundStyle(OnboardingTheme.primaryText)
                .multilineTextAlignment(textAlignment)
                .minimumScaleFactor(headlineStyle == .screen ? 0.72 : 0.8)
                .lineLimit(headlineStyle == .screen ? 3 : 2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: frameAlignment)
                .accessibilityAddTraits(.isHeader)

            if let supporting {
                Text(supporting)
                    .font(OnboardingMarketingTypography.supporting)
                    .foregroundStyle(OnboardingTheme.secondaryText)
                    .multilineTextAlignment(textAlignment)
                    .minimumScaleFactor(0.85)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var headlineFont: Font {
        switch headlineStyle {
        case .screen: OnboardingMarketingTypography.screenHeadline
        case .vision: OnboardingMarketingTypography.visionHeadline
        }
    }

    private var textAlignment: TextAlignment {
        alignment == .center ? .center : .leading
    }

    private var frameAlignment: Alignment {
        alignment == .center ? .center : .leading
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 32) {
        OnboardingHeroSection(
            headline: "Your personalized coach is waiting.",
            supporting: "You don't need more motivation."
        )
        OnboardingHeroSection(
            headline: "This becomes your new normal.",
            supporting: "Stay near 70 kg without second-guessing every meal.",
            headlineStyle: .vision
        )
    }
    .padding()
    .background(OnboardingTheme.background)
    .formaThemePreview()
}
#endif
