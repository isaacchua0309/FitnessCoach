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
    var showsSuccessHandoff: Bool = false

    @Environment(\.onboardingPlanRevealLayoutProfile) private var layoutProfile
    @Environment(\.onboardingPlanRevealIsCompactWidth) private var isCompactWidth

    @ScaledMetric(relativeTo: .largeTitle) private var compactHeroFontSize: CGFloat = 32
    @ScaledMetric(relativeTo: .largeTitle) private var regularHeroFontSize: CGFloat = 38
    @ScaledMetric(relativeTo: .largeTitle) private var expansiveHeroFontSize: CGFloat = 44

    private var heroFontSize: CGFloat {
        switch layoutProfile {
        case .compact: compactHeroFontSize
        case .regular: regularHeroFontSize
        case .expansive: expansiveHeroFontSize
        }
    }

    var body: some View {
        Group {
            if layoutProfile.usesExpandedGoalHero {
                expandedLayout
            } else {
                compactHorizontalLayout
            }
        }
        .onboardingPlanRevealCardPadding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { OnboardingPlanRevealCardBackground(surface: .goalHero) }
        .onboardingPlanRevealGoalSweep()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(badge). \(headline). \(strategyLabel)")
    }

    private var compactHorizontalLayout: some View {
        HStack(alignment: .center, spacing: FormaTokens.Spacing.sm) {
            heroCopy(alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)
            heroIllustration
                .layoutPriority(0)
        }
    }

    private var expandedLayout: some View {
        VStack(spacing: FormaTokens.Spacing.sm) {
            heroIllustration
                .frame(maxWidth: .infinity)
            heroCopy(alignment: .center)
                .frame(maxWidth: .infinity)
        }
    }

    private func heroCopy(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: FormaTokens.Spacing.xs) {
            OnboardingPlanRevealSectionHeader(title: badge, usesHeaderTrait: false)
                .foregroundStyle(OnboardingTheme.accent)
                .tracking(0.5)
                .accessibilityHidden(true)
                .onboardingPlanRevealEntrance(.achievementBadge)

            VStack(alignment: alignment, spacing: FormaTokens.Spacing.xs) {
                Text(headline)
                    .font(.system(size: heroFontSize, weight: .bold, design: .rounded))
                    .foregroundStyle(OnboardingTheme.primaryText)
                    .multilineTextAlignment(alignment == .center ? .center : .leading)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .accessibilityAddTraits(.isHeader)

                Text(strategyLabel)
                    .font(FormaTokens.Typography.caption.weight(.semibold))
                    .foregroundStyle(OnboardingTheme.secondaryText)
                    .multilineTextAlignment(alignment == .center ? .center : .leading)
                    .lineLimit(isCompactWidth ? 1 : 2)
                    .minimumScaleFactor(0.75)
            }
            .onboardingPlanRevealEntrance(.goalCard)
        }
    }

    private var heroIllustration: some View {
        OnboardingPlanRevealHeroIllustration(
            style: showsSuccessHandoff ? .successHandoff : .destination(direction)
        )
        .onboardingPlanRevealEntrance(.heroIllustration)
    }
}

#if DEBUG
#Preview("Compact") {
    OnboardingPlanRevealGoalHeroCard(
        badge: FormaProductCopy.Onboarding.V2.PlanReveal.Cards.destinationBadge,
        headline: "Reach 70 kg",
        strategyLabel: "Moderate cut",
        direction: .cut
    )
    .environment(\.onboardingPlanRevealLayoutProfile, .compact)
    .padding()
    .background(OnboardingTheme.background)
    .formaThemePreview()
}

#Preview("Expansive") {
    OnboardingPlanRevealGoalHeroCard(
        badge: FormaProductCopy.Onboarding.V2.PlanReveal.Cards.destinationBadge,
        headline: "Reach 70 kg",
        strategyLabel: "Moderate cut",
        direction: .cut
    )
    .environment(\.onboardingPlanRevealLayoutProfile, .expansive)
    .padding()
    .background(OnboardingTheme.background)
    .formaThemePreview()
}
#endif
