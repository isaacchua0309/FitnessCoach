//
//  OnboardingAppleHealthPermissionSummaryCard.swift
//  Fitness Coach
//
//  Forma — Permission summary for Apple Health onboarding.
//

import SwiftUI

struct OnboardingAppleHealthPermissionSummaryCard: View {
    let title: String
    let items: [(icon: String, title: String)]

    var body: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
            Text(title)
                .font(FormaTokens.Typography.body.weight(.semibold))
                .foregroundStyle(OnboardingTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: FormaTokens.Spacing.xs) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    permissionRow(icon: item.icon, title: item.title)
                }
            }
        }
        .padding(OnboardingLayout.compactCardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: OnboardingTheme.cornerRadius, style: .continuous)
                .fill(OnboardingTheme.card)
        )
        .overlay {
            RoundedRectangle(cornerRadius: OnboardingTheme.cornerRadius, style: .continuous)
                .stroke(OnboardingTheme.border.opacity(0.55), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(FormaProductCopy.Onboarding.Flow.AppleHealth.readableDataAccessibilityLabel)
    }

    private func permissionRow(icon: String, title: String) -> some View {
        HStack(spacing: FormaTokens.Spacing.sm) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(OnboardingTheme.accent)
                .frame(width: 22, alignment: .center)
                .accessibilityHidden(true)

            Text(title)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(OnboardingTheme.primaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, FormaTokens.Spacing.sm)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: FormaTokens.Radius.compact, style: .continuous)
                .fill(OnboardingTheme.surfaceSubtle)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }
}

#if DEBUG
#Preview {
    OnboardingAppleHealthPermissionSummaryCard(
        title: FormaProductCopy.Onboarding.Flow.AppleHealth.summaryCardTitle,
        items: FormaProductCopy.Onboarding.Flow.AppleHealth.permissionItems
    )
    .padding()
    .background(OnboardingTheme.background)
    .formaThemePreview()
}
#endif
