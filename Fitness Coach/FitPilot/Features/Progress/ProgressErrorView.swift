//
//  ProgressErrorView.swift
//  Fitness Coach
//
//  FitPilot AI — Error state for Progress.
//

import SwiftUI

struct ProgressErrorView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: FormaTokens.Spacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 44))
                .foregroundStyle(FormaTokens.Color.warning)

            Text(message)
                .font(FormaTokens.Typography.sectionTitle)
                .foregroundStyle(FormaTokens.Color.textPrimary)
                .multilineTextAlignment(.center)

            Button(FormaProductCopy.Common.retry, action: onRetry)
                .buttonStyle(.borderedProminent)
                .tint(FormaTokens.Color.accent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(FormaTokens.Color.canvas)
    }
}

#Preview {
    ProgressErrorView(message: FormaProductCopy.Error.loadJourney) {}
        .preferredColorScheme(.dark)
}
