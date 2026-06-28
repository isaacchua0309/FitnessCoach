//
//  OnboardingV4BiologicalSexSelector.swift
//  Fitness Coach
//
//  Forma — Male/female sex selector for v4 calorie calculation (Mifflin-St Jeor).
//

import SwiftUI

struct OnboardingV4BiologicalSexSelector: View {
    @Binding var selection: Sex

    private let options: [Sex] = [.male, .female]

    var body: some View {
        VStack(alignment: .leading, spacing: OnboardingLayout.compactLabelGap) {
            Text(FormaProductCopy.Onboarding.V4.Birthday.sexSectionTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(OnboardingTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: OnboardingLayout.compactFieldSpacing) {
                ForEach(options, id: \.self) { sex in
                    sexPill(for: sex)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(FormaProductCopy.Onboarding.V4.Birthday.sexSectionTitle)
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

#if DEBUG
#Preview {
    OnboardingV4BiologicalSexSelector(selection: .constant(.female))
        .padding()
        .background(OnboardingTheme.background)
        .preferredColorScheme(.dark)
}
#endif
