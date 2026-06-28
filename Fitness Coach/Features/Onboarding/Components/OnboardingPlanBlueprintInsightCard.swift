//
//  OnboardingPlanBlueprintInsightCard.swift
//  Fitness Coach
//
//  Forma — Personalized insight for plan blueprint review.
//

import SwiftUI

struct OnboardingPlanBlueprintInsightCard: View {
    let copy: String

    var body: some View {
        HStack(alignment: .top, spacing: FormaTokens.Spacing.sm) {
            Image(systemName: "sparkles")
                .font(.body.weight(.semibold))
                .foregroundStyle(OnboardingTheme.accent)
                .padding(.top, 2)
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
                .fill(FormaTokens.Color.surfaceSubtle.opacity(0.55))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(copy)
    }
}

#if DEBUG
#Preview {
    OnboardingPlanBlueprintInsightCard(
        copy: FormaProductCopy.Onboarding.Flow.Summary.Insight.loss
    )
    .padding()
    .background(OnboardingTheme.background)
    .formaThemePreview()
}
#endif
