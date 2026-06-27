//
//  OnboardingChoiceRow.swift
//  Fitness Coach
//
//  Forma — Compact selectable row for tap-first onboarding.
//

import SwiftUI

struct OnboardingChoiceRow: View {
    let icon: String
    let title: String
    var subtitle: String?
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var iconWidth: CGFloat = 24

    private var showsSubtitle: Bool {
        guard let subtitle, !subtitle.isEmpty else { return false }
        return dynamicTypeSize < .accessibility2
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: FormaTokens.Spacing.sm) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : icon)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(isSelected ? OnboardingTheme.accent : OnboardingTheme.secondaryText)
                    .frame(width: iconWidth)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                        .foregroundStyle(OnboardingTheme.primaryText)
                        .lineLimit(2)
                        .minimumScaleFactor(0.9)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if showsSubtitle, let subtitle {
                        Text(subtitle)
                            .font(FormaTokens.Typography.caption)
                            .foregroundStyle(OnboardingTheme.secondaryText)
                            .lineLimit(2)
                            .minimumScaleFactor(0.9)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, OnboardingLayout.compactCardPadding)
            .padding(.vertical, 10)
            .frame(minHeight: FormaTokens.Layout.minTouchTarget, alignment: .center)
            .background(
                RoundedRectangle(cornerRadius: OnboardingTheme.compactCornerRadius, style: .continuous)
                    .fill(isSelected ? FormaTokens.Color.accentMuted : FormaTokens.Color.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: OnboardingTheme.compactCornerRadius, style: .continuous)
                    .stroke(
                        isSelected ? OnboardingTheme.selectedBorder : OnboardingTheme.border,
                        lineWidth: isSelected ? 1.4 : 1
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: OnboardingTheme.compactCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabelText)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var accessibilityLabelText: String {
        if let subtitle, showsSubtitle {
            return "\(title), \(subtitle)"
        }
        return title
    }
}

#Preview("Choice rows") {
    VStack(spacing: FormaTokens.Spacing.sm) {
        OnboardingChoiceRow(
            icon: "leaf.fill",
            title: "Gentle",
            subtitle: "About 0.25% of body weight per week",
            isSelected: true,
            action: {}
        )
        OnboardingChoiceRow(
            icon: "gauge.medium",
            title: "Moderate",
            subtitle: "About 0.50% of body weight per week",
            isSelected: false,
            action: {}
        )
    }
    .padding()
    .background(OnboardingTheme.background)
    .preferredColorScheme(.dark)
}

#Preview("Large Dynamic Type") {
    OnboardingChoiceRow(
        icon: "figure.walk",
        title: "Moderately active",
        subtitle: "Regular workouts and daily movement",
        isSelected: true,
        action: {}
    )
    .padding()
    .background(OnboardingTheme.background)
    .preferredColorScheme(.dark)
    .dynamicTypeSize(.accessibility2)
}
