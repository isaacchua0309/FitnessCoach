//
//  OnboardingPlanBlueprintBasisCard.swift
//  Fitness Coach
//
//  Forma — Plan basis rows for blueprint review.
//

import SwiftUI

struct OnboardingPlanBlueprintBasisCard: View {
    let title: String
    let items: [OnboardingPlanBlueprintBasisItem]

    var body: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.md) {
            Text(title)
                .font(FormaTokens.Typography.body.weight(.semibold))
                .foregroundStyle(OnboardingTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: FormaTokens.Spacing.sm) {
                ForEach(items) { item in
                    HStack(spacing: FormaTokens.Spacing.md) {
                        Image(systemName: item.icon)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(OnboardingTheme.accent)
                            .frame(width: 24, height: 24)
                            .accessibilityHidden(true)

                        Text(item.title)
                            .font(FormaTokens.Typography.body)
                            .foregroundStyle(OnboardingTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(item.title)
                }
            }
        }
        .padding(FormaTokens.Spacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous)
                .fill(FormaTokens.Color.surfaceSubtle.opacity(0.72))
        )
        .accessibilityElement(children: .contain)
    }
}

#if DEBUG
#Preview {
    OnboardingPlanBlueprintBasisCard(
        title: FormaProductCopy.Onboarding.Flow.Summary.Basis.title,
        items: OnboardingPlanBlueprintBuilder.build(from: OnboardingPreviewData.formState).basisItems
    )
    .padding()
    .background(OnboardingTheme.background)
    .formaThemePreview()
}
#endif
