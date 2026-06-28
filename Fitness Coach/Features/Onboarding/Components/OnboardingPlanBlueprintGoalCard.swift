//
//  OnboardingPlanBlueprintGoalCard.swift
//  Fitness Coach
//
//  Forma — Goal summary card for plan blueprint review.
//

import SwiftUI

struct OnboardingPlanBlueprintGoalCard: View {
    let sectionTitle: String
    let heroMetric: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
            Text(sectionTitle)
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(OnboardingTheme.accent)
                .textCase(.uppercase)
                .accessibilityAddTraits(.isHeader)

            Text(heroMetric)
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(OnboardingTheme.primaryText)
                .minimumScaleFactor(0.8)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(subtitle)
                .font(FormaTokens.Typography.body)
                .foregroundStyle(OnboardingTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(FormaTokens.Spacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous)
                .fill(FormaTokens.Color.surfaceSubtle)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(sectionTitle). \(heroMetric). \(subtitle)")
    }
}

#if DEBUG
#Preview {
    OnboardingPlanBlueprintGoalCard(
        sectionTitle: "Your goal",
        heroMetric: "Lose 3.5 kg",
        subtitle: "From 70 kg to 66.5 kg"
    )
    .padding()
    .background(OnboardingTheme.background)
    .formaThemePreview()
}
#endif
