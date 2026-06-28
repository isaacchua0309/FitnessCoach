//
//  OnboardingPlanBlueprintInsightCard.swift
//  Fitness Coach
//
//  Forma — Coach insight card for plan blueprint milestone.
//

import SwiftUI

struct OnboardingPlanBlueprintCoachInsightCard: View {
    let title: String
    let bodyCopy: String

    var body: some View {
        HStack(alignment: .top, spacing: FormaTokens.Spacing.sm) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(OnboardingTheme.accent)
                .frame(width: 3)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
                Text(title)
                    .font(FormaTokens.Typography.body.weight(.semibold))
                    .foregroundStyle(OnboardingTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                Text(bodyCopy)
                    .font(FormaTokens.Typography.body)
                    .foregroundStyle(OnboardingTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(FormaTokens.Spacing.cardPadding)
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
    OnboardingPlanBlueprintCoachInsightCard(
        title: FormaProductCopy.Onboarding.Flow.Summary.Insight.lossTitle,
        bodyCopy: FormaProductCopy.Onboarding.Flow.Summary.Insight.loss
    )
    .padding()
    .background(OnboardingTheme.background)
    .formaThemePreview()
}
#endif
