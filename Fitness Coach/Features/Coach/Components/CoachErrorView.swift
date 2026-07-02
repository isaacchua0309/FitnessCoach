//
//  CoachErrorView.swift
//  Fitness Coach
//
//  FitPilot AI — Minimal inline error for Coach.
//

import SwiftUI

struct CoachErrorView: View {
    var title: String?
    let message: String
    var retryAction: (() -> Void)?
    var isRetrying: Bool = false
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: CoachDesignTokens.Spacing.sm) {
            VStack(alignment: .leading, spacing: CoachDesignTokens.Spacing.xs) {
                if let title {
                    Text(title)
                        .font(CoachDesignTokens.Typography.confirmationValue)
                        .foregroundStyle(CoachDesignTokens.Color.primaryText)
                }

                Text(message)
                    .font(CoachDesignTokens.Typography.confirmationMetric)
                    .foregroundStyle(CoachDesignTokens.Color.secondaryText)

                if let retryAction {
                    Button(action: retryAction) {
                        HStack(spacing: CoachDesignTokens.Spacing.xs) {
                            Text(FormaProductCopy.Common.retry)
                            if isRetrying {
                                SwiftUI.ProgressView()
                                    .controlSize(.small)
                            }
                        }
                    }
                    .font(CoachDesignTokens.Typography.confirmationMetric)
                    .foregroundStyle(CoachDesignTokens.Color.primary)
                    .disabled(isRetrying)
                }
            }
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
    CoachErrorView(
        title: AIServiceError.coachSessionFailureTitle,
        message: AIServiceError.coachSessionFailureMessage,
        retryAction: {},
        onDismiss: {}
    )
    .background(CoachDesignTokens.Color.background)
    .formaThemePreview()
}
