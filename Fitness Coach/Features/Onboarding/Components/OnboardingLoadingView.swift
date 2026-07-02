//
//  OnboardingLoadingView.swift
//  Fitness Coach
//
//  FitPilot AI — Loading overlay for Onboarding.
//

import SwiftUI

struct OnboardingLoadingView: View {
    let message: String

    var body: some View {
        VStack(spacing: 14) {
            SwiftUI.ProgressView()
                .tint(OnboardingTheme.primary)

            Text(message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(OnboardingTheme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .onboardingCard()
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    OnboardingLoadingView(message: FormaProductCopy.Loading.generatingPlan)
}
