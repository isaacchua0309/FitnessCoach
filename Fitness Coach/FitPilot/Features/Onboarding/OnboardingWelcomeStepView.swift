//
//  OnboardingWelcomeStepView.swift
//  Fitness Coach
//
//  FitPilot AI — Welcome step for onboarding.
//

import SwiftUI

struct OnboardingWelcomeStepView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "figure.run.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.blue)

            VStack(spacing: 8) {
                Text("FitPilot AI")
                    .font(.largeTitle.weight(.bold))
                Text("Your local-first fitness coach for nutrition, hydration, weight, and training.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 10) {
                featureRow("Track calories, macros, water, and workouts")
                featureRow("Get daily reviews and progress trends")
                featureRow("Chat with your coach using simple commands")
            }
            .padding()
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .frame(maxWidth: .infinity)
    }

    private func featureRow(_ text: String) -> some View {
        Label(text, systemImage: "checkmark.circle.fill")
            .font(.subheadline)
            .foregroundStyle(.primary)
    }
}

#Preview {
    OnboardingWelcomeStepView()
        .padding()
}
