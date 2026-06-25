//
//  CoachErrorView.swift
//  Fitness Coach
//
//  FitPilot AI — Minimal inline error for Coach.
//

import SwiftUI

struct CoachErrorView: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: CoachDesignTokens.Spacing.sm) {
            Text(message)
                .font(CoachDesignTokens.Typography.confirmationMetric)
                .foregroundStyle(CoachDesignTokens.Color.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(CoachDesignTokens.Color.tertiaryText)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, CoachDesignTokens.Layout.horizontalPadding)
        .padding(.vertical, CoachDesignTokens.Spacing.xs)
    }
}

#Preview {
    CoachErrorView(message: "Something went wrong.") {}
        .background(CoachDesignTokens.Color.background)
        .preferredColorScheme(.dark)
}
