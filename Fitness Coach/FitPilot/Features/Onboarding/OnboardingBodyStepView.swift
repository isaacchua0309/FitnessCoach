//
//  OnboardingBodyStepView.swift
//  Fitness Coach
//
//  FitPilot AI — Body details step for onboarding.
//

import SwiftUI

struct OnboardingBodyStepView: View {
    @Binding var formState: OnboardingFormState

    var body: some View {
        VStack(spacing: 16) {
            inputField("Age", text: $formState.ageText, keyboard: .numberPad)
            Picker("Sex", selection: $formState.sex) {
                ForEach(Sex.allCases, id: \.self) { sex in
                    Text(OnboardingFormatter.sex(sex)).tag(sex)
                }
            }
            .pickerStyle(.menu)

            inputField("Height (cm)", text: $formState.heightCmText, keyboard: .decimalPad)
            inputField("Current weight (kg)", text: $formState.currentWeightKgText, keyboard: .decimalPad)
            inputField("Body fat % (optional)", text: $formState.estimatedBodyFatPercentageText, keyboard: .decimalPad)

            Picker("Unit system", selection: $formState.unitSystem) {
                ForEach(UnitSystem.allCases, id: \.self) { system in
                    Text(OnboardingFormatter.unitSystem(system)).tag(system)
                }
            }
            .pickerStyle(.menu)

            Text("Values are stored in metric. Imperial is a display preference for now.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func inputField(_ title: String, text: Binding<String>, keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.medium))
            TextField(title, text: text)
                .keyboardType(keyboard)
                .textFieldStyle(.roundedBorder)
        }
    }
}

#Preview {
    OnboardingBodyStepView(formState: .constant(OnboardingPreviewData.formState))
        .padding()
}
