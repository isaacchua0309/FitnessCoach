//
//  OnboardingPlanRevealCoachCard.swift
//  Fitness Coach
//
//  Forma — Personal coach message for plan reveal.
//

import SwiftUI

struct OnboardingPlanRevealCoachCard: View {
    let message: String

    @Environment(\.onboardingPlanRevealIsCompactHeight) private var isCompactHeight
    @Environment(\.onboardingPlanRevealContentDensity) private var contentDensity
    @ScaledMetric(relativeTo: .body) private var markSize: CGFloat = 28

    private var coachLineLimit: Int {
        switch contentDensity {
        case .tight: 1
        case .compact: 2
        case .standard: isCompactHeight ? 2 : 3
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: FormaTokens.Spacing.sm) {
            FormaBrandMark(size: .small, accessibilityMode: .decorative)
                .frame(width: markSize, height: markSize)
                .accessibilityHidden(true)

            Text(message)
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(OnboardingTheme.secondaryText)
                .lineLimit(coachLineLimit)
                .minimumScaleFactor(0.75)
        }
        .onboardingPlanRevealCardPadding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { OnboardingPlanRevealCardBackground(surface: .coach) }
        .onboardingPlanRevealEntrance(.coach)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
    }
}

#if DEBUG
#Preview {
    OnboardingPlanRevealCoachCard(
        message: FormaProductCopy.Onboarding.V2.PlanReveal.Coach.cut(goalWeight: "70 kg")
    )
    .padding()
    .background(OnboardingTheme.background)
    .formaThemePreview()
}
#endif
