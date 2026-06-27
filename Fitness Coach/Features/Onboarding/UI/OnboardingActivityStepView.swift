//
//  OnboardingActivityStepView.swift
//  Fitness Coach
//
//  Forma — Combined activity step for v2 (chip-based, no keyboard).
//

import SwiftUI

struct OnboardingActivityStepView: View {
    @Binding var formState: OnboardingFormState

    private var isV2: Bool { OnboardingStepPolicy.isV2Enabled }

    var body: some View {
        VStack(alignment: .leading, spacing: OnboardingLayout.compactSectionSpacing) {
            OnboardingActivityLevelStepView(
                formState: $formState,
                showsEmbeddedHeader: !isV2
            )

            OnboardingTrainingRhythmStepView(
                formState: $formState,
                showsEmbeddedHeader: isV2
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("Valid") {
    OnboardingActivityStepView(formState: .constant(OnboardingPreviewData.formState))
        .padding()
        .background(OnboardingTheme.background)
        .preferredColorScheme(.dark)
}

#Preview("Incomplete") {
    OnboardingActivityStepView(
        formState: .constant({
            var state = OnboardingFormState()
            state.trainingFrequencyPerWeekText = ""
            state.averageStepsText = ""
            return state
        }())
    )
    .padding()
    .background(OnboardingTheme.background)
    .preferredColorScheme(.dark)
}

#Preview("iPhone SE") {
    OnboardingActivityStepView(formState: .constant(OnboardingPreviewData.formState))
        .padding()
        .background(OnboardingTheme.background)
        .preferredColorScheme(.dark)
        .previewDevice(PreviewDevice(rawValue: "iPhone SE (3rd generation)"))
}
