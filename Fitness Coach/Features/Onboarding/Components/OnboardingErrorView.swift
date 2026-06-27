//
//  OnboardingErrorView.swift
//  Fitness Coach
//
//  FitPilot AI — Inline error banner for Onboarding.
//

import SwiftUI

struct OnboardingErrorView: View {
    let message: String

    var body: some View {
        OnboardingWarningBanner(message: message)
    }
}

#Preview {
    OnboardingErrorView(message: FormaProductCopy.Onboarding.Validation.age)
        .padding()
}
