//
//  OnboardingSelectionCard.swift
//  Fitness Coach
//
//  FitPilot AI — Reusable tappable option row.
//

import SwiftUI

struct OnboardingSelectionCard: View {
    let title: String
    var subtitle: String?
    var icon: String = "circle"
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 13) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(isSelected ? OnboardingTheme.accent : OnboardingTheme.secondaryText)
                    .frame(width: 26)

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(OnboardingTheme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(OnboardingTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 0)
            }
            .onboardingCard(selected: isSelected)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(subtitle.map { "\(title), \($0)" } ?? title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
