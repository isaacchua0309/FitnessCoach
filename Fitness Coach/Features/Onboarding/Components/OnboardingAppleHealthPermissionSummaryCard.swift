//
//  OnboardingAppleHealthPermissionSummaryCard.swift
//  Fitness Coach
//
//  Forma — Compact permission summary for Apple Health onboarding.
//

import SwiftUI

struct OnboardingAppleHealthPermissionSummaryCard: View {
    let title: String
    let rows: [String]

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
        .accessibilityLabel(FormaProductCopy.Onboarding.Flow.AppleHealth.readableDataAccessibilityLabel)
    }
}

#if DEBUG
#Preview {
    OnboardingAppleHealthPermissionSummaryCard(
        title: FormaProductCopy.Onboarding.Flow.AppleHealth.summaryCardTitle,
        rows: FormaProductCopy.Onboarding.Flow.AppleHealth.readableDataRows
    )
    .padding()
    .background(OnboardingTheme.background)
    .formaThemePreview()
}
#endif
