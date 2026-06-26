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
        VStack(spacing: FormaTokens.Spacing.sm + 2) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(FormaTokens.Color.warning)

            Text(message)
                .font(FormaTokens.Typography.sectionTitle)
                .foregroundStyle(FormaTokens.Color.textPrimary)
                .multilineTextAlignment(.center)

            Button(FormaProductCopy.Common.tryAgain, action: onRetry)
                .buttonStyle(.borderedProminent)
                .tint(FormaTokens.Color.accent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FormaTokens.Color.canvas)
    }
}

#Preview {
    ProfileErrorView(message: FormaProductCopy.Error.loadProfile, onRetry: {})
        .preferredColorScheme(.dark)
}
