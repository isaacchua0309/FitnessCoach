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

struct FormaEstimateContextBanner: View {
    let confidence: AIConfidence
    let context: String?
    var sanityWarning: String?
    var estimatedCaloriesLine: String?
    var likelyRangeLine: String?
    var mainUncertaintyLine: String?
    var assumptionLines: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
            if let estimatedCaloriesLine, !estimatedCaloriesLine.isEmpty {
                Text(estimatedCaloriesLine)
                    .font(FormaTokens.Typography.body.weight(.semibold))
                    .foregroundStyle(FormaTokens.Color.textPrimary)
            }

            if let likelyRangeLine, !likelyRangeLine.isEmpty {
                Text(likelyRangeLine)
                    .font(FormaTokens.Typography.sectionSubtitle)
                    .foregroundStyle(FormaTokens.Color.textSecondary)
            }

            Text(AIFoodConfirmationFormatter.confidenceLabel(confidence))
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(confidenceLabelColor)

            if let mainUncertaintyLine, !mainUncertaintyLine.isEmpty {
                Text(mainUncertaintyLine)
                    .font(FormaTokens.Typography.sectionSubtitle)
                    .foregroundStyle(FormaTokens.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !assumptionLines.isEmpty {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.xxs) {
                    ForEach(Array(assumptionLines.prefix(3).enumerated()), id: \.offset) { _, line in
                        Text("• \(line)")
                            .font(FormaTokens.Typography.caption)
                            .foregroundStyle(FormaTokens.Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            if let sanityWarning, !sanityWarning.isEmpty {
                Text(sanityWarning)
                    .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                    .foregroundStyle(FormaTokens.Color.destructive)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let context, !context.isEmpty, assumptionLines.isEmpty {
                Text(context)
                    .font(FormaTokens.Typography.sectionSubtitle)
                    .foregroundStyle(FormaTokens.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else if estimatedCaloriesLine == nil {
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
