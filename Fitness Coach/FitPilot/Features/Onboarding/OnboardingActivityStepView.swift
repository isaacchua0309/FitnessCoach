//
//  OnboardingActivityStepView.swift
//  Fitness Coach
//
//  FitPilot AI — Activity step for onboarding.
//

import SwiftUI

struct OnboardingActivityStepView: View {
    @Binding var formState: OnboardingFormState
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case trainingDays
        case steps
    }

    var body: some View {
        VStack(alignment: .leading, spacing: OnboardingTheme.sectionSpacing) {
            OnboardingSectionTitle(
                title: "Training rhythm",
                subtitle: "This helps FitPilot estimate your baseline burn and recovery needs."
            )

            VStack(alignment: .leading, spacing: 10) {
                OnboardingSectionTitle(title: "Daily activity")

                ForEach(ActivityLevel.allCases, id: \.self) { level in
                    OnboardingSelectionCard(
                        title: OnboardingFormatter.activityLevel(level),
                        subtitle: OnboardingFormatter.activityLevelDescription(level),
                        icon: activityIcon(for: level),
                        isSelected: formState.activityLevel == level
                    ) {
                        focusedField = nil
                        formState.activityLevel = level
                    }
                }
            }

            VStack(spacing: OnboardingTheme.fieldSpacing) {
                OnboardingTextField(
                    title: "Training days per week",
                    placeholder: "3",
                    text: $formState.trainingFrequencyPerWeekText,
                    helper: "Strength, sport, classes, or structured cardio.",
                    keyboard: .numberPad
                )
                .focused($focusedField, equals: .trainingDays)

                OnboardingTextField(
                    title: "Average steps per day",
                    placeholder: "5000",
                    text: $formState.averageStepsText,
                    helper: "A rough weekly average is enough.",
                    keyboard: .numberPad
                )
                .focused($focusedField, equals: .steps)
            }
            .onboardingCard()
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
            }
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

#Preview {
    OnboardingActivityStepView(formState: .constant(OnboardingPreviewData.formState))
        .padding()
}
