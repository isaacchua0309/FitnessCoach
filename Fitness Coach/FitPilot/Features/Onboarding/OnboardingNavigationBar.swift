//
//  OnboardingNavigationBar.swift
//  Fitness Coach
//
//  FitPilot AI — Back/continue navigation for Onboarding.
//

import SwiftUI

struct OnboardingNavigationBar: View {
    let currentStep: OnboardingStep
    let isLoading: Bool
    let onBack: () -> Void
    let onContinue: () -> Void
    let onComplete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if currentStep != .welcome {
                Button("Back", action: onBack)
                    .buttonStyle(.bordered)
                    .disabled(isLoading)
            }

            Spacer()

            if currentStep == .planPreview {
                Button("Start FitPilot", action: onComplete)
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading)
            } else {
                Button(currentStep == .preferences ? "Generate Plan" : "Continue", action: onContinue)
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading)
            }
        }
    }
}

#Preview {
    OnboardingNavigationBar(
        currentStep: .goal,
        isLoading: false,
        onBack: {},
        onContinue: {},
        onComplete: {}
    )
    .padding()
}
