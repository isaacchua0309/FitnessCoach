//
//  OnboardingPlanBlueprintGoalCard.swift
//  Fitness Coach
//
//  Forma — Goal summary card for plan blueprint review.
//

import SwiftUI

struct OnboardingPlanBlueprintGoalCard: View {
    let heroMetric: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: OnboardingLayout.compactLabelGap) {
            Text(heroMetric)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(OnboardingTheme.primaryText)
                .minimumScaleFactor(0.8)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            Text(subtitle)
                .font(FormaTokens.Typography.body)
                .foregroundStyle(OnboardingTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(OnboardingLayout.compactCardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous)
                .fill(FormaTokens.Color.surfaceSubtle)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(heroMetric). \(subtitle)")
    }
}

#if DEBUG
#Preview {
    OnboardingPlanBlueprintGoalCard(
        heroMetric: "Lose 3.5 kg",
        subtitle: "70 kg → 66.5 kg"
    )
    .padding()
    .background(OnboardingTheme.background)
    .formaThemePreview()
}
#endif
