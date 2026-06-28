//
//  TrainingInsightsConnectedHeader.swift
//  Fitness Coach
//
//  Forma — In-screen header for connected Training Insights.
//

import SwiftUI

struct TrainingInsightsConnectedHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
            Text(TrainingIntegrationCopy.screenTitle)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(FormaTokens.Color.textPrimary)

            HStack(spacing: FormaTokens.Spacing.xs) {
                Image(systemName: "heart.fill")
                    .font(FormaTokens.Typography.caption.weight(.semibold))
                    .foregroundStyle(FormaTokens.Color.accent.opacity(0.9))

                Text(TrainingIntegrationCopy.poweredByAppleHealthStatus)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(FormaTokens.Color.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    TrainingInsightsConnectedHeader()
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}
