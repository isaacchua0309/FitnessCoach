//
//  OnboardingProgressHeader.swift
//  Fitness Coach
//
//  FitPilot AI — Step progress header for Onboarding.
//

import SwiftUI

struct OnboardingProgressHeader: View {
    let currentStep: OnboardingStep

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Step \(currentStep.progressIndex) of \(OnboardingStep.totalSteps)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            SwiftUI.ProgressView(value: Double(currentStep.progressIndex), total: Double(OnboardingStep.totalSteps))
                .tint(.blue)

            Text(currentStep.title)
                .font(.title2.weight(.bold))

            Text(currentStep.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    OnboardingProgressHeader(currentStep: .body)
        .padding()
}
