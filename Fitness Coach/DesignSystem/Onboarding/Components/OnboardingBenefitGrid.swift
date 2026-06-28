//
//  OnboardingBenefitGrid.swift
//  Fitness Coach
//
//  Forma — Static benefit list card for onboarding marketing screens.
//

import SwiftUI

struct OnboardingBenefitGrid: View {
    let benefits: [OnboardingBenefitItem]
    let accessibilityLabel: String

    @ScaledMetric(relativeTo: .body) private var iconSize = OnboardingVisual.benefitIconCompact

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(benefits.enumerated()), id: \.element.id) { index, benefit in
                if index > 0 {
                    benefitDivider
                }
                benefitRow(benefit)
                    .frame(maxHeight: .infinity)
            }
        }
        .padding(.horizontal, FormaTokens.Spacing.lg)
        .padding(.vertical, FormaTokens.Spacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(cardBackground)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous)
            .fill(OnboardingGradients.cardAccentWash)
            .overlay(
                RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous)
                    .stroke(OnboardingTheme.border.opacity(OnboardingVisual.neutralCardBorderOpacity), lineWidth: 1)
            )
    }

    private var benefitDivider: some View {
        Rectangle()
            .fill(OnboardingTheme.border.opacity(0.28))
            .frame(height: 0.5)
            .padding(.vertical, FormaTokens.Spacing.sm)
    }

    private func benefitRow(_ benefit: OnboardingBenefitItem) -> some View {
        HStack(alignment: .center, spacing: FormaTokens.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: FormaTokens.Radius.compact, style: .continuous)
                    .fill(OnboardingTheme.accent.opacity(0.12))
                    .frame(width: iconSize + 18, height: iconSize + 18)

                Image(systemName: benefit.icon)
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundStyle(OnboardingTheme.accent)
                    .symbolRenderingMode(.hierarchical)
            }
            .accessibilityHidden(true)

            Text(benefit.title)
                .font(OnboardingMarketingTypography.benefitTitlePlain)
                .foregroundStyle(OnboardingTheme.primaryText)
                .minimumScaleFactor(0.85)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(benefit.title)
    }
}

#if DEBUG
#Preview {
    let state = OnboardingFormaProofBuilder.build(
        from: {
            var state = OnboardingFormState()
            OnboardingHeightWeightValues.setWeightKg(70, in: &state)
            OnboardingTargetWeightValues.setGoalFromDeltaKg(0, in: &state)
            return state
        }()
    )
    OnboardingBenefitGrid(
        benefits: OnboardingFormaProofBuilder.benefitItems(from: state),
        accessibilityLabel: state.benefitsAccessibilityLabel
    )
    .frame(height: 220)
    .padding()
    .background(OnboardingTheme.background)
    .formaThemePreview()
}
#endif
