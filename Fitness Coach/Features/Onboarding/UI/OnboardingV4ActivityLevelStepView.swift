//
//  OnboardingV4ActivityLevelStepView.swift
//  Fitness Coach
//
//  Forma — V4 simplified activity level selection (no manual training rhythm).
//

import SwiftUI

struct OnboardingV4ActivityLevelStepView: View {
    @Binding var formState: OnboardingFormState

    var body: some View {
        OnboardingCompactSelectionList {
            ForEach(Array(OnboardingV4ActivityLevelValues.orderedLevels.enumerated()), id: \.element) { index, level in
                if index > 0 {
                    Divider()
                        .overlay(OnboardingTheme.border.opacity(0.55))
                }

                OnboardingCompactSelectionRow(
                    title: OnboardingFormatter.activityLevel(level),
                    subtitle: OnboardingV4ActivityLevelValues.optionDescription(for: level),
                    icon: activityIcon(for: level),
                    isSelected: formState.activityLevel == level
                ) {
                    OnboardingV4ActivityLevelValues.select(level, in: &formState)
                }
            }
        }
        .accessibilityLabel(FormaProductCopy.Onboarding.V4.Activity.optionsAccessibilityLabel)
        .animation(.easeInOut(duration: 0.18), value: formState.activityLevel)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            OnboardingV4ActivityLevelValues.applyDefaultsIfNeeded(to: &formState)
        }
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

#if DEBUG
#Preview("V4 Activity Level") {
    OnboardingV4ActivityLevelStepView(formState: .constant(OnboardingPreviewData.formState))
        .padding()
        .background(OnboardingTheme.background)
        .preferredColorScheme(.dark)
}
#endif
