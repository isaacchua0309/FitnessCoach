//
//  OnboardingActivityLevelExplanationCard.swift
//  Fitness Coach
//
//  Forma — Inline selected-explanation preview for activity level onboarding.
//

import SwiftUI

struct OnboardingActivityLevelExplanationCard: View {
    let state: OnboardingActivityLevelExplanationState

    var body: some View {
        Text(state.headline)
            .font(FormaTokens.Typography.caption)
            .foregroundStyle(
                state.isPlaceholder
                    ? OnboardingTheme.secondaryText
                    : OnboardingTheme.primaryText.opacity(0.82)
            )
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentTransition(.opacity)
            .animation(.easeOut(duration: 0.2), value: state.headline)
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
