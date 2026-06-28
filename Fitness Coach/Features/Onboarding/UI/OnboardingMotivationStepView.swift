//
//  OnboardingMotivationStepView.swift
//  Fitness Coach
//
//  Forma — Optional motivation selections for onboarding (compact, tap-first).
//

import SwiftUI

struct OnboardingMotivationStepView: View {
    @Binding var formState: OnboardingFormState

    private var isAtSelectionLimit: Bool {
        formState.selectedMotivations.count >= OnboardingMotivation.maxSelectionCount
    }

    var body: some View {
        OnboardingCompactSelectionList {
            ForEach(Array(OnboardingMotivation.allCases.enumerated()), id: \.element.id) { index, motivation in
                if index > 0 {
                    Divider()
                        .overlay(OnboardingTheme.border.opacity(0.55))
                }

                MotivationCompactRow(
                    motivation: motivation,
                    isSelected: formState.selectedMotivations.contains(motivation),
                    isDisabled: isAtSelectionLimit && !formState.selectedMotivations.contains(motivation)
                ) {
                    formState.toggleMotivation(motivation)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Motivation options")
        .animation(.easeInOut(duration: 0.18), value: formState.selectedMotivations)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Compact row

private struct MotivationCompactRow: View {
    let motivation: OnboardingMotivation
    let isSelected: Bool
    let isDisabled: Bool
    let action: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var showsSubtitle: Bool {
        dynamicTypeSize < .accessibility1
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : motivation.symbolName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(
                        isSelected ? OnboardingTheme.accent : OnboardingTheme.secondaryText.opacity(0.82)
                    )
                    .frame(width: 22)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(motivation.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(OnboardingTheme.primaryText)
                        .lineLimit(2)
                        .minimumScaleFactor(0.9)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if showsSubtitle {
                        Text(motivation.subtitle)
                            .font(.caption)
                            .foregroundStyle(OnboardingTheme.secondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.9)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, 7)
            .padding(.horizontal, OnboardingLayout.compactCardPadding)
            .frame(minHeight: FormaTokens.Layout.minTouchTarget, alignment: .center)
            .background(isSelected ? FormaTokens.Color.accentMuted : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.42 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(isDisabled ? "Deselect another option first" : "")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var accessibilityLabel: String {
        if showsSubtitle {
            return "\(motivation.title), \(motivation.subtitle)"
        }
        return motivation.title
    }
}

// MARK: - Previews

#Preview("Empty") {
    OnboardingMotivationStepView(formState: .constant(OnboardingFormState()))
        .padding()
        .background(OnboardingTheme.background)
        .preferredColorScheme(.dark)
}

#Preview("One selected") {
    OnboardingMotivationStepView(
        formState: .constant({
            var state = OnboardingFormState()
            state.selectedMotivations = [.confidence]
            return state
        }())
    )
    .padding()
    .background(OnboardingTheme.background)
    .preferredColorScheme(.dark)
}

#Preview("Two selected") {
    OnboardingMotivationStepView(
        formState: .constant({
            var state = OnboardingFormState()
            state.selectedMotivations = [.confidence, .performance]
            return state
        }())
    )
    .padding()
    .background(OnboardingTheme.background)
    .preferredColorScheme(.dark)
}



#Preview("Large Dynamic Type") {
    OnboardingMotivationStepView(
        formState: .constant({
            var state = OnboardingFormState()
            state.selectedMotivations = [.lowStress]
            return state
        }())
    )
    .padding()
    .background(OnboardingTheme.background)
    .preferredColorScheme(.dark)
    .dynamicTypeSize(.accessibility2)
}
