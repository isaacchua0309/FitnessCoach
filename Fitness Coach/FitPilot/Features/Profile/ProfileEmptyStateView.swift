//
//  ProfileEmptyStateView.swift
//  Fitness Coach
//
//  FitPilot AI — Onboarding entry for My Plan.
//

import SwiftUI

struct ProfileEmptyStateView: View {
    let onCreateProfile: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Build your plan")
                .font(.title2.weight(.bold))

            Text("Tell FitPilot about your goal and we'll create a personalized calorie, macro, and training blueprint.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Get Started", action: onCreateProfile)
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ProfileEmptyStateView(onCreateProfile: {})
}
