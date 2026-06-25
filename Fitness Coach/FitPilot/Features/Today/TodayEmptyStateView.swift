//
//  TodayEmptyStateView.swift
//  Fitness Coach
//
//  FitPilot AI — Empty state before profile/onboarding exists.
//

import SwiftUI

struct TodayEmptyStateView: View {
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)

            Text("Set Up Your Profile")
                .font(.title3.bold())

            Text("Create your profile first so FitPilot can generate targets and start today's log.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Try Again", action: onRetry)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

#Preview {
    TodayEmptyStateView {}
}
