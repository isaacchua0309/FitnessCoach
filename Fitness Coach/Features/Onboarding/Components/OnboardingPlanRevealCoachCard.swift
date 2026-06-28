//
//  OnboardingPlanRevealCoachCard.swift
//  Fitness Coach
//
//  Forma — Personal coach message for plan reveal.
//

import SwiftUI

struct OnboardingPlanRevealCoachCard: View {
    let message: String

    @ScaledMetric(relativeTo: .body) private var markSize: CGFloat = 28

    var body: some View {
        HStack(alignment: .top, spacing: FormaTokens.Spacing.sm) {
            FormaBrandMark(size: .small, accessibilityMode: .decorative)
                .frame(width: markSize, height: markSize)
                .accessibilityHidden(true)

            Text(message)
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(OnboardingTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, OnboardingLayout.compactCardPadding)
        .padding(.vertical, FormaTokens.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: FormaTokens.Radius.compact, style: .continuous)
                .fill(FormaTokens.Color.accentMuted.opacity(0.35))
        )
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
