//
//  FormaEstimateContextBanner.swift
//  Fitness Coach
//
//  Forma — Read-only AI estimate context for Coach food edit.
//

import SwiftUI

struct FormaEstimateContextBanner: View {
    let confidence: AIConfidence
    let context: String?

    var body: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
            Text(AIFoodConfirmationFormatter.confidenceLabel(confidence))
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(FormaTokens.Color.accent)

            if let context, !context.isEmpty {
                Text(context)
                    .font(FormaTokens.Typography.sectionSubtitle)
                    .foregroundStyle(FormaTokens.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(AIFoodConfirmationFormatter.confirmationWarning(confidence: confidence))
                    .font(FormaTokens.Typography.sectionSubtitle)
                    .foregroundStyle(FormaTokens.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(FormaTokens.Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: FormaTokens.Radius.compact, style: .continuous)
                .fill(FormaTokens.Color.accentMuted)
        }
        .overlay {
            RoundedRectangle(cornerRadius: FormaTokens.Radius.compact, style: .continuous)
                .stroke(FormaTokens.Color.border, lineWidth: 1)
        }
    }
}
