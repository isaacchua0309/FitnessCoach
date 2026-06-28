//
//  OnboardingFormaProofBenefitsList.swift
//  Fitness Coach
//
//  Forma — Concise future-vision benefits for forma proof onboarding.
//

import SwiftUI

struct OnboardingFormaProofBenefitsList: View {
    let benefits: [OnboardingFormaProofBenefit]
    let accessibilityLabel: String

    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 22

    var body: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.lg) {
            ForEach(benefits) { benefit in
                benefitRow(benefit)
            }
        }
        .padding(.horizontal, FormaTokens.Spacing.lg)
        .padding(.vertical, FormaTokens.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous)
                .fill(OnboardingTheme.cardElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous)
                        .stroke(OnboardingTheme.border.opacity(0.4), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
    }

    private func benefitRow(_ benefit: OnboardingFormaProofBenefit) -> some View {
        HStack(alignment: .center, spacing: FormaTokens.Spacing.md) {
            Image(systemName: benefit.icon)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(OnboardingTheme.accent)
                .symbolRenderingMode(.hierarchical)
                .frame(width: iconSize + 6, alignment: .center)
                .accessibilityHidden(true)

            Text(benefit.title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(OnboardingTheme.primaryText)
                .minimumScaleFactor(0.85)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(benefit.title)
    }
}

#if DEBUG
#Preview {
    OnboardingFormaProofBenefitsList(
        benefits: OnboardingFormaProofBuilder.build(
            from: {
                var state = OnboardingFormState()
                OnboardingHeightWeightValues.setWeightKg(70, in: &state)
                OnboardingTargetWeightValues.setGoalFromDeltaKg(0, in: &state)
                return state
            }()
        ).benefits,
        accessibilityLabel: "What changes: Guardrails, not restrictions. Catch drift before it sticks. Balance you can live with."
    )
    .padding()
    .background(OnboardingTheme.background)
    .formaThemePreview()
}
#endif
