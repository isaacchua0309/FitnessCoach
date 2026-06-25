//
//  CoachEmptyStateView.swift
//  Fitness Coach
//
//  FitPilot AI — Empty state shown before any chat messages exist.
//

import SwiftUI

struct CoachEmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)

            Text("Talk to your Coach")
                .font(.title3.bold())

            Text("Try logging quickly with commands like \"new day\", \"+500ml\", \"weight 90.15\", or \"status\".")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

#Preview {
    CoachEmptyStateView()
}
