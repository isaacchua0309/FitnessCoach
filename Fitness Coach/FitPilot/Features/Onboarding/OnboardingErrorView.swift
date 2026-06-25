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
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.orange)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#Preview {
    OnboardingErrorView(message: "Please enter a valid age.")
        .padding()
}
