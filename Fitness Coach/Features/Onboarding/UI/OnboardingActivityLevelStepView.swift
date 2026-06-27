//
//  OnboardingActivityLevelStepView.swift
//  Fitness Coach
//
//  Forma — Activity level only (Screen A of tap-first activity onboarding).
//

import SwiftUI

struct OnboardingActivityLevelStepView: View {
    @Binding var formState: OnboardingFormState
    var showsEmbeddedHeader: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: OnboardingLayout.compactSectionSpacing) {
            if showsEmbeddedHeader {
                embeddedHeader
            }

            OnboardingCompactSelectionList {
                ForEach(Array(ActivityLevel.allCases.enumerated()), id: \.element) { index, level in
                    if index > 0 {
                        Divider()
                            .overlay(OnboardingTheme.border.opacity(0.55))
                    }

                    OnboardingCompactSelectionRow(
                        title: OnboardingFormatter.activityLevel(level),
                        subtitle: OnboardingFormatter.activityLevelDescription(level),
                        icon: activityIcon(for: level),
                        isSelected: formState.activityLevel == level
                    ) {
                        formState.selectActivityLevel(level)
                    }
                }
            }
            .accessibilityLabel("Activity level options")
        }
        .animation(.easeInOut(duration: 0.18), value: formState.activityLevel)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var embeddedHeader: some View {
        OnboardingSectionTitle(
            title: FormaProductCopy.Onboarding.V2.Activity.title,
            subtitle: FormaProductCopy.Onboarding.V2.Activity.subtitle
        )
    }

    private func activityIcon(for level: ActivityLevel) -> String {
        switch level {
        case .sedentary:
            return "chair.fill"
        case .lightlyActive:
            return "figure.walk"
        case .moderatelyActive:
            return "figure.run"
        case .veryActive:
            return "figure.strengthtraining.traditional"
        case .athlete:
            return "bolt.heart.fill"
        }
    }
}

#Preview("Sedentary") {
    OnboardingActivityLevelStepView(
        formState: .constant({
            var state = OnboardingFormState()
            state.activityLevel = .sedentary
            return state
        }())
    )
    .padding()
    .background(OnboardingTheme.background)
    .preferredColorScheme(.dark)
}

#Preview("Moderately active") {
    OnboardingActivityLevelStepView(formState: .constant(OnboardingPreviewData.formState))
        .padding()
        .background(OnboardingTheme.background)
        .preferredColorScheme(.dark)
}

#Preview("Athlete") {
    OnboardingActivityLevelStepView(
        formState: .constant({
            var state = OnboardingFormState()
            state.activityLevel = .athlete
            return state
        }())
    )
    .padding()
    .background(OnboardingTheme.background)
    .preferredColorScheme(.dark)
}

#Preview("iPhone SE") {
    OnboardingActivityLevelStepView(formState: .constant(OnboardingPreviewData.formState))
        .padding()
        .background(OnboardingTheme.background)
        .preferredColorScheme(.dark)
        .previewDevice(PreviewDevice(rawValue: "iPhone SE (3rd generation)"))
}

#Preview("Large iPhone") {
    OnboardingActivityLevelStepView(formState: .constant(OnboardingPreviewData.formState))
        .padding()
        .background(OnboardingTheme.background)
        .preferredColorScheme(.dark)
        .previewDevice(PreviewDevice(rawValue: "iPhone 15 Pro Max"))
}
