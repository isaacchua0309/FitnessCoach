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
    @Environment(\.onboardingFieldNavigator) private var fieldNavigator

    private enum Field: String, Hashable {
        case trainingDays
        case steps
    }

    var body: some View {
        VStack(alignment: .leading, spacing: OnboardingTheme.sectionSpacing) {
            OnboardingSectionTitle(
                title: "Training rhythm",
                subtitle: FormaProductCopy.Onboarding.activityBaselineSubtitle
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
                OnboardingNumberField(
                    title: "Training days per week",
                    placeholder: "3",
                    text: $formState.trainingFrequencyPerWeekText,
                    helper: "Strength, sport, classes, or structured cardio.",
                    keyboard: .numberPad,
                    isFocused: focusedField == .trainingDays
                )
                .focused($focusedField, equals: .trainingDays)
                .id(Field.trainingDays)

                OnboardingNumberField(
                    title: "Average steps per day",
                    placeholder: "5000",
                    text: $formState.averageStepsText,
                    helper: "A rough weekly average is enough.",
                    keyboard: .numberPad,
                    isFocused: focusedField == .steps
                )
                .focused($focusedField, equals: .steps)
                .id(Field.steps)
            }
        }
        .onChange(of: focusedField) { _, field in
            syncNavigator(for: field)
        }
        .onAppear {
            syncNavigator(for: focusedField)
        }
    }

    private func syncNavigator(for field: Field?) {
        guard let fieldNavigator else { return }

        switch field {
        case .trainingDays:
            fieldNavigator.updateFocus(
                fieldID: Field.trainingDays,
                canPrevious: false,
                canNext: true,
                onPrevious: nil,
                onNext: { focusedField = .steps },
                onDismiss: { focusedField = nil }
            )
        case .steps:
            fieldNavigator.updateFocus(
                fieldID: Field.steps,
                canPrevious: true,
                canNext: false,
                onPrevious: { focusedField = .trainingDays },
                onNext: nil,
                onDismiss: { focusedField = nil }
            )
        case nil:
            fieldNavigator.clearFocus()
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
        .environment(\.onboardingFieldNavigator, OnboardingFieldNavigator())
}
