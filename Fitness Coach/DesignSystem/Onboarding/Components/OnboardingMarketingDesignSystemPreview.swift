//
//  OnboardingMarketingDesignSystemPreview.swift
//  Fitness Coach
//
//  Forma — Preview catalog for onboarding marketing design system components.
//

import SwiftUI

#if DEBUG
enum OnboardingMarketingDesignSystemPreview {

    @ViewBuilder
    static var catalog: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.xl) {
                heroSection
                goalCard
                illustrationContainer
                transformationCard
                benefitGrid
                footerMessage
                primaryCTA
            }
            .padding(OnboardingTheme.pagePadding)
        }
        .background(OnboardingTheme.background)
    }

    @ViewBuilder
    private static var heroSection: some View {
        sectionTitle("HeroSection")
        OnboardingHeroSection(
            headline: "Your personalized coach is waiting.",
            supporting: "You don't need more motivation."
        )
    }

    @ViewBuilder
    private static var goalCard: some View {
        sectionTitle("GoalCard")
        OnboardingGoalCard(intentLabel: "Maintain", metric: "70 kg", showsStabilityBand: true)
    }

    @ViewBuilder
    private static var illustrationContainer: some View {
        sectionTitle("IllustrationContainer")
        OnboardingIllustrationContainer(
            style: .targetRing(
                intentLabel: "Maintain",
                weightLabel: "70 kg",
                pathStyle: .maintain,
                ringProgress: 1
            )
        )
    }

    @ViewBuilder
    private static var transformationCard: some View {
        sectionTitle("TransformationCard")
        OnboardingTransformationCard(
            benefits: OnboardingAlmostThereValues.benefits,
            accessibilityLabel: OnboardingAlmostThereValues.benefitsAccessibilityLabel
        )
    }

    @ViewBuilder
    private static var benefitGrid: some View {
        sectionTitle("BenefitGrid")
        OnboardingBenefitGrid(
            benefits: [
                OnboardingBenefitItem(icon: "shield.lefthalf.filled", title: "Guardrails, not restrictions"),
                OnboardingBenefitItem(icon: "bell.badge", title: "Catch drift before it sticks"),
                OnboardingBenefitItem(icon: "heart.fill", title: "Balance you can live with")
            ],
            accessibilityLabel: "Benefits"
        )
    }

    @ViewBuilder
    private static var footerMessage: some View {
        sectionTitle("FooterMessage")
        OnboardingFooterMessage(message: "Built from your body, goal, and activity level.")
    }

    @ViewBuilder
    private static var primaryCTA: some View {
        sectionTitle("PrimaryCTA")
        OnboardingPrimaryCTA(title: "Review my blueprint", action: {})
    }

  @ViewBuilder
  private static func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(FormaTokens.Typography.caption.weight(.semibold))
            .foregroundStyle(OnboardingTheme.tertiaryText)
            .textCase(.uppercase)
    }
}

#Preview("Marketing design system") {
    OnboardingMarketingDesignSystemPreview.catalog
        .formaThemePreview()
}
#endif
