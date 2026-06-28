//
//  OnboardingBirthdayStepView.swift
//  Fitness Coach
//
//  Forma — birthday wheel and biological sex capture for calorie targets.
//

import SwiftUI

struct OnboardingBirthdayStepView: View {
    @Binding var formState: OnboardingFormState

    var body: some View {
        VStack(alignment: .leading, spacing: OnboardingLayout.compactSectionSpacing) {
            OnboardingBirthdayWheelPicker(birthDate: $formState.birthDate)
                .onChange(of: formState.birthDate) { _, _ in
                    formState.syncAgeTextFromBirthDate()
                }

            OnboardingBiologicalSexSelector(selection: $formState.sex)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            OnboardingBirthdayValues.applyDefaultsIfNeeded(to: &formState)
        }
    }
}

#if DEBUG
#Preview("Birthday") {
    OnboardingBirthdayStepView(
        formState: .constant({
            var state = OnboardingFormState()
            OnboardingBirthdayValues.applyDefaultsIfNeeded(to: &state)
            state.sex = .female
            return state
        }())
    )
    .padding()
    .background(OnboardingTheme.background)
}
#endif
