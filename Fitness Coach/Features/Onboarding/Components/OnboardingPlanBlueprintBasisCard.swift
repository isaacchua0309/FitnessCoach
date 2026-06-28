//
//  OnboardingPlanBlueprintBasisCard.swift
//  Fitness Coach
//
//  Forma — Compact chip basis for blueprint review.
//

import SwiftUI

struct OnboardingPlanBlueprintBasisCard: View {
    let title: String
    let items: [OnboardingPlanBlueprintBasisItem]

    var body: some View {
        VStack(alignment: .leading, spacing: OnboardingLayout.compactLabelGap) {
            Text(title)
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(OnboardingTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            CoachFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(items) { item in
                    chip(title: item.title)
                }
            }
        }
        .padding(OnboardingLayout.compactCardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous)
                .fill(FormaTokens.Color.surfaceSubtle.opacity(0.72))
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(title). \(items.map(\.title).joined(separator: ", "))")
    }

    private func chip(title: String) -> some View {
        Text(title)
            .font(FormaTokens.Typography.caption.weight(.medium))
            .foregroundStyle(OnboardingTheme.secondaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(FormaTokens.Color.surfaceSubtle.opacity(0.9))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(OnboardingTheme.border.opacity(0.45), lineWidth: 0.5)
            )
            .accessibilityLabel(title)
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
