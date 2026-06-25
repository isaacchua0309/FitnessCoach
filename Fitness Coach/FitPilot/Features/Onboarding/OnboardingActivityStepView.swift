//
//  OnboardingActivityStepView.swift
//  Fitness Coach
//
//  FitPilot AI — Activity step for onboarding.
//

import SwiftUI

struct OnboardingActivityStepView: View {
    @Binding var formState: OnboardingFormState

    var body: some View {
        VStack(spacing: 16) {
            Picker("Activity level", selection: $formState.activityLevel) {
                ForEach(ActivityLevel.allCases, id: \.self) { level in
                    Text(OnboardingFormatter.activityLevel(level)).tag(level)
                }
            }
            .pickerStyle(.menu)

            VStack(alignment: .leading, spacing: 6) {
                Text("Training days per week")
                    .font(.subheadline.weight(.medium))
                TextField("Training days per week", text: $formState.trainingFrequencyPerWeekText)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Average steps per day")
                    .font(.subheadline.weight(.medium))
                TextField("Average steps per day", text: $formState.averageStepsText)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }
}

#Preview {
    OnboardingActivityStepView(formState: .constant(OnboardingPreviewData.formState))
        .padding()
}
