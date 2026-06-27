//
//  OnboardingSexPillGrid.swift
//  Fitness Coach
//
//  Forma — Compact 2×2 sex selector for onboarding body basics.
//

import SwiftUI

struct OnboardingSexPillGrid: View {
    @Binding var selection: Sex

    private let columns = [
        GridItem(.flexible(), spacing: OnboardingLayout.compactFieldSpacing),
        GridItem(.flexible(), spacing: OnboardingLayout.compactFieldSpacing)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: OnboardingLayout.compactFieldSpacing) {
            ForEach(Sex.allCases, id: \.self) { sex in
                sexPill(for: sex)
            }
        }
        .accessibilityLabel(FormaProductCopy.Onboarding.V2.Body.genderLabel)
    }

    private func sexPill(for sex: Sex) -> some View {
        let isSelected = selection == sex

        return Button {
            selection = sex
        } label: {
            Text(OnboardingFormatter.sex(sex))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? OnboardingTheme.primaryText : OnboardingTheme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity)
                .frame(minHeight: FormaTokens.Layout.minTouchTarget)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: OnboardingTheme.compactCornerRadius, style: .continuous)
                        .fill(isSelected ? FormaTokens.Color.accentMuted : Color.white.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: OnboardingTheme.compactCornerRadius, style: .continuous)
                        .stroke(
                            isSelected ? OnboardingTheme.selectedBorder : OnboardingTheme.border,
                            lineWidth: isSelected ? 1.4 : 1
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(OnboardingFormatter.sex(sex))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview {
    OnboardingSexPillGrid(selection: .constant(.female))
        .padding()
        .background(OnboardingTheme.background)
        .preferredColorScheme(.dark)
}
