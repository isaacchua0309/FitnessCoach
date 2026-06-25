//
//  ProfileEmptyStateView.swift
//  Fitness Coach
//
//  FitPilot AI — Empty state for Profile.
//

import SwiftUI

struct ProfileEmptyStateView: View {
    let onCreateProfile: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.blue)

            VStack(spacing: 6) {
                Text("No profile set up yet.")
                    .font(.title3.weight(.semibold))
                Text("Create a basic profile so FitPilot can calculate your calorie, macro, and water targets.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("Create Default Profile", action: onCreateProfile)
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ProfileEmptyStateView(onCreateProfile: {})
}
