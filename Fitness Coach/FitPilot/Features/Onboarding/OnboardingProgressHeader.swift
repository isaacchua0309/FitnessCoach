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
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Step \(currentStep.progressIndex) of \(OnboardingStep.totalSteps)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(OnboardingTheme.accent)
                    .textCase(.uppercase)
                    .tracking(0.6)

                Spacer()

                Text("\(Int(progress * 100))%")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(OnboardingTheme.secondaryText)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.1))

                    Capsule()
                        .fill(OnboardingTheme.accent)
                        .frame(width: max(proxy.size.width * progress, 8))
                }
            }
            .frame(height: 7)
            .accessibilityLabel("Onboarding progress")
            .accessibilityValue("Step \(currentStep.progressIndex) of \(OnboardingStep.totalSteps)")

            VStack(alignment: .leading, spacing: 8) {
                Text(currentStep.title)
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .foregroundStyle(OnboardingTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text(currentStep.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(OnboardingTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var progress: Double {
        Double(currentStep.progressIndex) / Double(OnboardingStep.totalSteps)
    }
}

#Preview {
    OnboardingProgressHeader(currentStep: .body)
        .padding()
}
