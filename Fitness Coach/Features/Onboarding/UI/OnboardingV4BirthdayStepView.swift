//
//  OnboardingV4BirthdayStepView.swift
//  Fitness Coach
//
//  Forma — V4 birthday wheel and biological sex capture for calorie targets.
//

import SwiftUI

struct OnboardingV4BirthdayStepView: View {
    @Binding var formState: OnboardingFormState

    var body: some View {
        VStack(alignment: .leading, spacing: OnboardingLayout.compactSectionSpacing) {
            OnboardingV4BirthdayWheelPicker(birthDate: $formState.birthDate)
                .onChange(of: formState.birthDate) { _, _ in
                    formState.syncAgeTextFromBirthDate()
                }

            OnboardingV4BiologicalSexSelector(selection: $formState.sex)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            OnboardingV4BirthdayValues.applyDefaultsIfNeeded(to: &formState)
        }
    }
}

#if DEBUG
#Preview("V4 Birthday") {
    OnboardingV4BirthdayStepView(
        formState: .constant({
            var state = OnboardingFormState()
            OnboardingV4BirthdayValues.applyDefaultsIfNeeded(to: &state)
            state.sex = .female
            return state
        }())
    )
    .padding()
    .background(OnboardingTheme.background)
}
#endif
