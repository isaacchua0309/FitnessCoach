//
//  OnboardingPlanRevealGoalHeroCard.swift
//  Fitness Coach
//
//  Forma — Goal destination hero for plan reveal.
//

import SwiftUI

struct OnboardingPlanRevealGoalHeroCard: View {
    let badge: String
    let headline: String
    let strategyLabel: String
    let direction: PlanGoalDirection

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @ScaledMetric(relativeTo: .largeTitle) private var heroFontSize: CGFloat = 36

    private var resolvedHeroFontSize: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? min(heroFontSize, 32) : heroFontSize
    }

    var body: some View {
        HStack(alignment: .center, spacing: FormaTokens.Spacing.sm) {
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
                Text(badge.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(OnboardingTheme.accent)
                    .tracking(0.5)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .accessibilityHidden(true)

                Text(headline)
                    .font(.system(size: resolvedHeroFontSize, weight: .bold, design: .rounded))
                    .foregroundStyle(OnboardingTheme.primaryText)
                    .minimumScaleFactor(0.72)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                Text(strategyLabel)
                    .font(FormaTokens.Typography.caption.weight(.semibold))
                    .foregroundStyle(OnboardingTheme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

            Spacer(minLength: FormaTokens.Spacing.xs)

            OnboardingPlanRevealDestinationIllustration(direction: direction)
        }
        .padding(.horizontal, OnboardingLayout.compactCardPadding)
        .padding(.vertical, FormaTokens.Spacing.sm + 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { goalHeroBackground }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(badge). \(headline). \(strategyLabel)")
    }

    private var goalHeroBackground: some View {
        RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        FormaTokens.Color.accentMuted.opacity(0.85),
                        FormaTokens.Color.surfaceSubtle
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous)
                    .stroke(OnboardingTheme.accent.opacity(0.18), lineWidth: 1)
            }
    }
}

#if DEBUG
#Preview {
    OnboardingPlanRevealGoalHeroCard(
        badge: FormaProductCopy.Onboarding.V2.PlanReveal.Cards.destinationBadge,
        headline: "Reach 70 kg",
        strategyLabel: "Moderate cut",
        direction: .cut
    )
    .padding()
    .background(OnboardingTheme.background)
    .formaThemePreview()
}
#endif
