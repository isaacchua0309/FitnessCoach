//
//  TodayErrorView.swift
//  Fitness Coach
//
//  FitPilot AI — Error state for Today.
//

import SwiftUI

struct TodayErrorView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 44))
                .foregroundStyle(.orange)

            Text(message)
                .font(.headline)
                .multilineTextAlignment(.center)

            Button("Retry", action: onRetry)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

#Preview {
    TodayErrorView(message: "Could not load today's log.") {}
}
