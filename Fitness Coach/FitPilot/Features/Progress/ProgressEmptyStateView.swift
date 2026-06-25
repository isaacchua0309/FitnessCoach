//
//  ProgressEmptyStateView.swift
//  Fitness Coach
//
//  FitPilot AI — Empty state for Progress.
//

import SwiftUI

struct ProgressEmptyStateView: View {
    let onRefresh: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)

            Text("Build Your Trend")
                .font(.title3.bold())

            Text("Progress trends become more accurate after 14-28 days of consistent logging.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Refresh", action: onRefresh)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

#Preview {
    ProgressEmptyStateView {}
}
