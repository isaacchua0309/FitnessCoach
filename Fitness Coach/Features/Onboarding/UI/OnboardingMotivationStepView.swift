//
//  OnboardingMotivationStepView.swift
//  Fitness Coach
//
//  Forma — Optional motivation selections for onboarding v2.
//

import SwiftUI

struct OnboardingMotivationStepView: View {
    @Binding var formState: OnboardingFormState

    private var feedbackMessage: String? {
        guard !formState.selectedMotivations.isEmpty else { return nil }
        return OnboardingMotivation.feedbackMessage(for: formState.selectedMotivations)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: OnboardingLayout.compactSectionSpacing) {
            OnboardingCompactSelectionList {
                ForEach(Array(OnboardingMotivation.allCases.enumerated()), id: \.element.id) { index, motivation in
                    if index > 0 {
                        Divider().overlay(OnboardingTheme.border)
                    }

                    OnboardingCompactSelectionRow(
                        title: motivation.title,
                        subtitle: motivation.subtitle,
                        icon: motivation.symbolName,
                        isSelected: formState.selectedMotivations.contains(motivation)
                    ) {
                        formState.toggleMotivation(motivation)
                    }
                }
            }
            .accessibilityLabel("Motivation options")

            if let feedbackMessage {
                Text(feedbackMessage)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(OnboardingTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .accessibilityLabel(
                        "\(FormaProductCopy.Onboarding.V2.Motivation.feedbackTitle). \(feedbackMessage)"
                    )
            }
        }
        .animation(.easeInOut(duration: 0.2), value: formState.selectedMotivations)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("Empty") {
    OnboardingMotivationStepView(formState: .constant(OnboardingFormState()))
        .padding()
        .background(OnboardingTheme.background)
        .preferredColorScheme(.dark)
}

#Preview("With selection") {
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

#Preview("iPhone SE") {
    OnboardingMotivationStepView(formState: .constant(OnboardingFormState()))
        .padding()
        .background(OnboardingTheme.background)
        .preferredColorScheme(.dark)
        .previewDevice(PreviewDevice(rawValue: "iPhone SE (3rd generation)"))
}

#Preview("Large Dynamic Type") {
    OnboardingMotivationStepView(
        formState: .constant({
            var state = OnboardingFormState()
            state.selectedMotivations = [.health]
            return state
        }())
    )
    .padding()
    .background(OnboardingTheme.background)
    .preferredColorScheme(.dark)
    .dynamicTypeSize(.accessibility2)
}
