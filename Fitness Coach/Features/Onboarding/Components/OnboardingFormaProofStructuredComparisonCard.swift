//
//  OnboardingFormaProofStructuredComparisonCard.swift
//  Fitness Coach
//
//  Forma — Honest structured comparison for forma proof onboarding.
//

import SwiftUI

struct OnboardingFormaProofStructuredComparisonCard: View {
    let state: OnboardingFormaProofComparisonState

    var body: some View {
        VStack(alignment: .leading, spacing: OnboardingLayout.compactFieldSpacing) {
            comparisonColumn(
                title: state.withoutTitle,
                headline: state.withoutHeadline,
                bullets: state.withoutBullets,
                accent: OnboardingTheme.secondaryText
            )

            Divider()
                .opacity(0.35)

            comparisonColumn(
                title: state.withTitle,
                headline: state.withHeadline,
                bullets: state.withBullets,
                accent: OnboardingTheme.accent
            )
        }
        .padding(OnboardingLayout.compactCardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous)
                .fill(FormaTokens.Color.surfaceSubtle)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(state.accessibilityLabel)
    }

    private func comparisonColumn(
        title: String,
        headline: String,
        bullets: [String],
        accent: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
            Text(title)
                .font(FormaTokens.Typography.caption2.weight(.semibold))
                .foregroundStyle(accent)
                .textCase(.uppercase)
                .accessibilityAddTraits(.isHeader)

            Text(headline)
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(OnboardingTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(bullets, id: \.self) { bullet in
                    HStack(alignment: .top, spacing: FormaTokens.Spacing.xs) {
                        Circle()
                            .fill(accent.opacity(0.85))
                            .frame(width: 4, height: 4)
                            .padding(.top, 6)
                            .accessibilityHidden(true)

                        Text(bullet)
                            .font(FormaTokens.Typography.caption)
                            .foregroundStyle(OnboardingTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#if DEBUG
#Preview {
    OnboardingFormaProofStructuredComparisonCard(
        state: OnboardingFormaProofBuilder.build(
            from: {
                var state = OnboardingFormState()
                OnboardingHeightWeightValues.setWeightKg(70, in: &state)
                OnboardingTargetWeightValues.setGoalFromLossKg(3.5, in: &state)
                return state
            }()
        ).comparison
    )
    .padding()
    .background(OnboardingTheme.background)
    .formaThemePreview()
}
#endif
