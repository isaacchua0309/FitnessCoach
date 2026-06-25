//
//  ProfileErrorView.swift
//  Fitness Coach
//
//  FitPilot AI — Error state for Profile.
//

import SwiftUI

struct ProfileErrorView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(.orange)

            Text(message)
                .font(.headline)
                .multilineTextAlignment(.center)

            Button("Try Again", action: onRetry)
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ProfileErrorView(message: "Could not load your profile.", onRetry: {})
}
