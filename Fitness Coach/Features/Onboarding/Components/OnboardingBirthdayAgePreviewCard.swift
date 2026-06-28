//
//  OnboardingBirthdayAgePreviewCard.swift
//  Fitness Coach
//
//  Forma — Compact inline age preview for birthday onboarding.
//

import SwiftUI

struct OnboardingBirthdayAgePreviewCard: View {
    let state: OnboardingBirthdayAgePreviewState

    var body: some View {
        HStack(alignment: .top, spacing: FormaTokens.Spacing.sm) {
            Image(systemName: state.isPlaceholder ? "calendar" : "person.crop.circle")
                .font(.body.weight(.semibold))
                .foregroundStyle(
                    state.isPlaceholder
                        ? OnboardingTheme.secondaryText
                        : OnboardingTheme.accent
                )
                .frame(width: 20, height: 20)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(state.headline)
                    .font(FormaTokens.Typography.body.weight(.semibold))
                    .foregroundStyle(
                        state.isPlaceholder
                            ? OnboardingTheme.secondaryText
                            : OnboardingTheme.primaryText
                    )
                    .minimumScaleFactor(0.85)
                    .lineLimit(1)
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.18), value: state.headline)

                Text(state.supportingCopy)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(OnboardingTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, OnboardingLayout.compactCardPadding)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: FormaTokens.Radius.compact, style: .continuous)
                .fill(FormaTokens.Color.surfaceSubtle)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(state.accessibilityLabel)
    }
}

#if DEBUG
#Preview("Age Preview") {
    VStack(spacing: 16) {
        OnboardingBirthdayAgePreviewCard(
            state: OnboardingBirthdayAgePreviewBuilder.build(
                from: {
                    var state = OnboardingFormState()
                    OnboardingBirthdayValues.applyDefaultsIfNeeded(to: &state)
                    return state
                }()
            )
        )
        OnboardingBirthdayAgePreviewCard(
            state: OnboardingBirthdayAgePreviewBuilder.build(from: OnboardingFormState())
        )
    }
    .padding()
    .background(OnboardingTheme.background)
    .preferredColorScheme(.dark)
}
#endif
