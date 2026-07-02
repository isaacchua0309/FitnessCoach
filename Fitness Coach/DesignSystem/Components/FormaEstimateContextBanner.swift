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
    var sanityWarning: String?

    var body: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
            Text(AIFoodConfirmationFormatter.confidenceLabel(confidence))
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(confidenceLabelColor)

            if let sanityWarning, !sanityWarning.isEmpty {
                Text(sanityWarning)
                    .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                    .foregroundStyle(FormaTokens.Color.destructive)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let context, !context.isEmpty {
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
                .fill(confidenceBackgroundColor)
        }
        .overlay {
            RoundedRectangle(cornerRadius: FormaTokens.Radius.compact, style: .continuous)
                .stroke(
                    sanityWarning == nil ? FormaTokens.Color.border : FormaTokens.Color.destructive.opacity(0.35),
                    lineWidth: 1
                )
        }
    }

    private var confidenceLabelColor: Color {
        switch confidence {
        case .low:
            FormaTokens.Color.warning
        case .medium, .high:
            FormaTokens.Theme.primary
        }
    }

    private var confidenceBackgroundColor: Color {
        switch confidence {
        case .low:
            FormaTokens.Color.warning.opacity(0.12)
        case .medium, .high:
            FormaTokens.Theme.softBackground
        }
    }
}
