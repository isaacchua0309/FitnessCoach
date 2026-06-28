//
//  OnboardingAlmostThereValueSection.swift
//  Fitness Coach
//
//  Forma — Compact "What you'll get" checklist for the almost-there milestone.
//

import SwiftUI

struct OnboardingAlmostThereValueSection: View {
    let title: String
    let rows: [String]
    let accessibilityLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: OnboardingLayout.compactFieldSpacing) {
            Text(title)
                .font(FormaTokens.Typography.body.weight(.semibold))
                .foregroundStyle(OnboardingTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: OnboardingLayout.compactLabelGap) {
                ForEach(rows, id: \.self) { row in
                    HStack(alignment: .center, spacing: FormaTokens.Spacing.sm) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(OnboardingTheme.accent)
                            .accessibilityHidden(true)

                        Text(row)
                            .font(FormaTokens.Typography.sectionSubtitle)
                            .foregroundStyle(OnboardingTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(row)
                }
            }
        }
        .padding(OnboardingLayout.compactCardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous)
                .fill(FormaTokens.Color.surfaceSubtle)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
    }
}

#if DEBUG
#Preview {
    OnboardingAlmostThereValueSection(
        title: FormaProductCopy.Onboarding.Flow.AlmostThere.valueSectionTitle,
        rows: OnboardingAlmostThereValues.valueRows,
        accessibilityLabel: OnboardingAlmostThereValues.valueSectionAccessibilityLabel
    )
    .padding()
    .background(OnboardingTheme.background)
    .formaThemePreview()
}
#endif
