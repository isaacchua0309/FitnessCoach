//
//  OnboardingBiologicalSexSelector.swift
//  Fitness Coach
//
//  Forma — Male/female sex selector for calorie calculation (Mifflin-St Jeor).
//

import SwiftUI

struct OnboardingBiologicalSexSelector: View {
    @Binding var selection: Sex

    var sectionTitle: String = FormaProductCopy.Onboarding.Flow.Birthday.sexSectionTitle
    var explanation: String = FormaProductCopy.Onboarding.Flow.Birthday.sexExplanation

    private let options: [Sex] = [.male, .female]

    var body: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
                Text(sectionTitle)
                    .font(FormaTokens.Typography.sectionTitle)
                    .foregroundStyle(OnboardingTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text(explanation)
                    .font(FormaTokens.Typography.sectionSubtitle)
                    .foregroundStyle(OnboardingTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: FormaTokens.Spacing.sm) {
                ForEach(options, id: \.self) { sex in
                    sexPill(for: sex)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(sectionTitle)
    }

    private func sexPill(for sex: Sex) -> some View {
        let isSelected = selection == sex
        let label = OnboardingFormatter.sex(sex)

        return Button {
            selection = sex
            OnboardingHaptics.selectionChanged()
        } label: {
            HStack(spacing: FormaTokens.Spacing.xs) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(FormaTokens.Typography.body.weight(.semibold))
                        .foregroundStyle(OnboardingTheme.accent)
                        .accessibilityHidden(true)
                }

                Text(label)
                    .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                    .foregroundStyle(isSelected ? OnboardingTheme.primaryText : OnboardingTheme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: FormaTokens.Layout.minTouchTarget + 8)
            .padding(.horizontal, FormaTokens.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: FormaTokens.Radius.button, style: .continuous)
                    .fill(isSelected ? FormaTokens.Color.accentMuted : FormaTokens.Color.surfaceSubtle)
            )
            .overlay(
                RoundedRectangle(cornerRadius: FormaTokens.Radius.button, style: .continuous)
                    .stroke(
                        isSelected ? OnboardingTheme.selectedBorder : Color.clear,
                        lineWidth: isSelected ? 1.5 : 0
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isSelected ? "\(label), selected" : label)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

#if DEBUG
#Preview {
    OnboardingBiologicalSexSelector(selection: .constant(.female))
        .padding()
        .background(OnboardingTheme.background)
        .formaThemePreview()
}
#endif
