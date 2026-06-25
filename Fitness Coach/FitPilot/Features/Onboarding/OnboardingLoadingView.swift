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
        VStack(spacing: 12) {
            SwiftUI.ProgressView()
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}

#Preview {
    OnboardingLoadingView(message: "Generating your plan...")
}
