//
//  OnboardingGoalStepView.swift
//  Fitness Coach
//
//  FitPilot AI — Goal step for onboarding.
//

import SwiftUI

struct OnboardingGoalStepView: View {
    @Binding var formState: OnboardingFormState

    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Goal weight (kg)")
                    .font(.subheadline.weight(.medium))
                TextField("Goal weight (kg)", text: $formState.goalWeightKgText)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Calorie pace")
                    .font(.subheadline.weight(.medium))

                ForEach(CalorieAggressiveness.allCases, id: \.self) { level in
                    Button {
                        formState.aggressiveness = level
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: formState.aggressiveness == level ? "largecircle.fill.circle" : "circle")
                                .foregroundStyle(formState.aggressiveness == level ? .blue : .secondary)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(OnboardingFormatter.aggressiveness(level))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text(OnboardingFormatter.aggressivenessDescription(level))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer()
                        }
                        .padding()
                        .background(
                            formState.aggressiveness == level
                                ? Color.blue.opacity(0.08)
                                : Color.clear,
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(
                                    formState.aggressiveness == level ? Color.blue.opacity(0.3) : Color.secondary.opacity(0.2),
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

#Preview {
    OnboardingGoalStepView(formState: .constant(OnboardingPreviewData.formState))
        .padding()
}
