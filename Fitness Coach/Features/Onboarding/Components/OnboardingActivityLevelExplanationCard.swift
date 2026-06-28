//
//  OnboardingActivityLevelExplanationCard.swift
//  Fitness Coach
//
//  Forma — Live explanation card for activity level onboarding.
//

import SwiftUI

struct OnboardingActivityLevelExplanationCard: View {
    let state: OnboardingActivityLevelExplanationState

    var body: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
            Text(state.headline)
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(
                    state.isPlaceholder
                        ? OnboardingTheme.secondaryText
                        : OnboardingTheme.primaryText
                )
                .minimumScaleFactor(0.85)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
                .animation(.easeOut(duration: 0.2), value: state.headline)

            Text(state.supportingCopy)
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
        .accessibilityLabel(state.accessibilityLabel)
    }
}

#if DEBUG
#Preview("Explanation") {
    VStack(spacing: 16) {
        OnboardingActivityLevelExplanationCard(
            state: OnboardingActivityLevelExplanationBuilder.build(
                from: {
                    var state = OnboardingFormState()
                    OnboardingActivityLevelValues.select(.moderatelyActive, in: &state)
                    return state
                }()
            )
        )
        OnboardingActivityLevelExplanationCard(
            state: OnboardingActivityLevelExplanationBuilder.build(from: OnboardingFormState())
        )
    }
    .padding()
    .background(OnboardingTheme.background)
    .formaThemePreview()
}
#endif
