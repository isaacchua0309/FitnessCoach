//
//  OnboardingActivityLevelCard.swift
//  Fitness Coach
//
//  Forma — Full-width selectable activity level card for onboarding.
//

import SwiftUI

struct OnboardingActivityLevelCard: View {
    let level: ActivityLevel
    let isSelected: Bool
    let action: () -> Void

    private var title: String {
        OnboardingFormatter.activityLevel(level)
    }

    private var subtitle: String {
        OnboardingActivityLevelValues.optionDescription(for: level)
    }

    private var icon: String {
        OnboardingActivityLevelValues.icon(for: level)
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: FormaTokens.Spacing.md) {
                Image(systemName: icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(isSelected ? OnboardingTheme.accent : OnboardingTheme.secondaryText)
                    .frame(width: 28, height: 28)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
                    Text(title)
                        .font(FormaTokens.Typography.body.weight(.semibold))
                        .foregroundStyle(OnboardingTheme.primaryText)
                        .lineLimit(2)
                        .minimumScaleFactor(0.9)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(subtitle)
                        .font(FormaTokens.Typography.caption)
                        .foregroundStyle(OnboardingTheme.secondaryText)
                        .lineLimit(2)
                        .minimumScaleFactor(0.9)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(OnboardingTheme.accent)
                        .transition(.scale.combined(with: .opacity))
                        .accessibilityHidden(true)
                }
            }
            .padding(FormaTokens.Spacing.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: FormaTokens.Layout.minTouchTarget + 12)
            .background(cardBackground)
            .overlay(cardBorder)
            .contentShape(RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            OnboardingActivityLevelExplanationBuilder.voiceOverLabel(
                for: level,
                isSelected: isSelected
            )
        )
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous)
            .fill(isSelected ? FormaTokens.Color.accentMuted : FormaTokens.Color.surfaceSubtle)
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous)
            .stroke(
                isSelected ? OnboardingTheme.selectedBorder : OnboardingTheme.border.opacity(0.35),
                lineWidth: isSelected ? 1.5 : 1
            )
    }
}

#if DEBUG
#Preview("Activity Cards") {
    VStack(spacing: 12) {
        OnboardingActivityLevelCard(level: .moderatelyActive, isSelected: true, action: {})
        OnboardingActivityLevelCard(level: .sedentary, isSelected: false, action: {})
    }
    .padding()
    .background(OnboardingTheme.background)
    .preferredColorScheme(.dark)
}
#endif
