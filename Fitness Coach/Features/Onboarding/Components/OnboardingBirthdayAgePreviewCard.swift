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
        HStack(alignment: .center, spacing: FormaTokens.Spacing.md) {
            Image(systemName: state.isPlaceholder ? "calendar" : "person.crop.circle.fill")
                .font(.title2.weight(.semibold))
                .foregroundStyle(
                    state.isPlaceholder
                        ? OnboardingTheme.secondaryText
                        : OnboardingTheme.accent
                )
                .frame(width: 32, height: 32)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
                Text(state.headline)
                    .font(.system(.title3, design: .rounded).weight(.bold))
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
                    .font(FormaTokens.Typography.sectionSubtitle)
                    .foregroundStyle(OnboardingTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, FormaTokens.Spacing.md)
        .padding(.vertical, FormaTokens.Spacing.md)
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
    .formaThemePreview()
}
#endif
