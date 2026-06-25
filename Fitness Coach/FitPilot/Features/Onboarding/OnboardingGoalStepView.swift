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

    private enum Field: Hashable {
        case goalWeight
    }

    var body: some View {
        VStack(alignment: .leading, spacing: OnboardingTheme.sectionSpacing) {
            OnboardingSectionTitle(
                title: "Set your destination",
                subtitle: "Pick a realistic goal weight and a pace that will not wreck training or recovery."
            )

            OnboardingTextField(
                title: "Goal weight",
                placeholder: "76",
                text: $formState.goalWeightKgText,
                helper: "Kilograms",
                keyboard: .decimalPad
            )
            .focused($focusedField, equals: .goalWeight)
            .onboardingCard()

            VStack(alignment: .leading, spacing: 10) {
                OnboardingSectionTitle(
                    title: "Calorie pace",
                    subtitle: "You can adjust this later once FitPilot sees your trend."
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
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
            }
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
}
