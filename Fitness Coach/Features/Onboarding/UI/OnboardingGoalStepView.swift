//
//  OnboardingGoalStepView.swift
//  Fitness Coach
//
//  FitPilot AI — Goal step for onboarding.
//

import SwiftUI

struct OnboardingGoalStepView: View {
    @Binding var formState: OnboardingFormState
    @FocusState private var focusedField: Field?
    @Environment(\.onboardingFieldNavigator) private var fieldNavigator

    private enum Field: String, Hashable {
        case goalWeight
    }

    var body: some View {
        VStack(alignment: .leading, spacing: OnboardingTheme.sectionSpacing) {
            OnboardingSectionTitle(
                title: "Set your destination",
                subtitle: FormaProductCopy.Onboarding.goalSubtitle
            )

            OnboardingNumberField(
                title: "Goal weight",
                placeholder: "76",
                text: $formState.goalWeightKgText,
                helper: "Kilograms",
                keyboard: .decimalPad,
                isFocused: focusedField == .goalWeight
            )
            .focused($focusedField, equals: .goalWeight)
            .id(Field.goalWeight)

            VStack(alignment: .leading, spacing: 10) {
                OnboardingSectionTitle(
                    title: "Calorie pace",
                    subtitle: FormaProductCopy.Onboarding.goalPaceSubtitle
                )

                ForEach(CalorieAggressiveness.allCases, id: \.self) { level in
                    OnboardingSelectionCard(
                        title: OnboardingFormatter.aggressiveness(level),
                        subtitle: OnboardingFormatter.aggressivenessDescription(level),
                        icon: icon(for: level),
                        isSelected: formState.aggressiveness == level
                    ) {
                        focusedField = nil
                        formState.aggressiveness = level
                    }
                }
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
        case .goalWeight:
            fieldNavigator.updateFocus(
                fieldID: Field.goalWeight,
                canPrevious: false,
                canNext: false,
                onPrevious: nil,
                onNext: nil,
                onDismiss: { focusedField = nil }
            )
        case nil:
            fieldNavigator.clearFocus()
        }
    }

    private func icon(for level: CalorieAggressiveness) -> String {
        switch level {
        case .conservative:
            return "leaf.fill"
        case .moderate:
            return "gauge.medium"
        case .aggressive:
            return "flame.fill"
        }
    }
}

#Preview {
    OnboardingGoalStepView(formState: .constant(OnboardingPreviewData.formState))
        .padding()
        .environment(\.onboardingFieldNavigator, OnboardingFieldNavigator())
}
