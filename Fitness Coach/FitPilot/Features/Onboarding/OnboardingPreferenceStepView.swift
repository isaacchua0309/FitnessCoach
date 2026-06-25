//
//  OnboardingPreferenceStepView.swift
//  Fitness Coach
//
//  FitPilot AI — Preferences step for onboarding.
//

import SwiftUI

struct OnboardingPreferenceStepView: View {
    @Binding var formState: OnboardingFormState

    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Name (optional)")
                    .font(.subheadline.weight(.medium))
                TextField("Name", text: $formState.name)
                    .textInputAutocapitalization(.words)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Diet preference (optional)")
                    .font(.subheadline.weight(.medium))
                TextField("e.g. high protein, flexible carbs", text: $formState.dietPreference, axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(.roundedBorder)
            }

            Text("You can update these anytime in Profile settings.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    OnboardingPreferenceStepView(formState: .constant(OnboardingPreviewData.formState))
        .padding()
}
