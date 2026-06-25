//
//  ProgressEmptyStateView.swift
//  Fitness Coach
//
//  FitPilot AI — Compact empty state when profile is missing.
//

import SwiftUI

struct ProgressEmptyStateView: View {
    let onRefresh: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Text("Your transformation story starts in Coach")
                .font(.title3.weight(.semibold))

            Text("Log weight, food, or water with Coach to see how you're becoming healthier.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Refresh", action: onRefresh)
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

#Preview {
    ProgressEmptyStateView {}
}
