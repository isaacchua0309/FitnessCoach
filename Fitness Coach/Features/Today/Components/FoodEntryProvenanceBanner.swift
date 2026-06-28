//
//  FoodEntryProvenanceBanner.swift
//  Fitness Coach
//
//  Forma — Source and confidence badges for logged food entries.
//

import SwiftUI

struct FoodEntryProvenanceBanner: View {
    let source: FoodEntrySource
    let confidence: ConfidenceLevel

    private var shouldShow: Bool {
        source != .manual || confidence != .high
    }

    var body: some View {
        if shouldShow {
            HStack(spacing: FormaTokens.Spacing.sm) {
                if source != .manual {
                    badge(
                        AIFoodConfirmationFormatter.sourceLabel(source),
                        accessibilityLabel: "Source: \(AIFoodConfirmationFormatter.sourceLabel(source))"
                    )
                }
                if confidence != .high {
                    badge(
                        FoodEntryFormFormatter.confidenceLabel(confidence),
                        accessibilityLabel: FoodEntryFormFormatter.confidenceLabel(confidence)
                    )
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func badge(_ title: String, accessibilityLabel: String) -> some View {
        Text(title)
            .font(FormaTokens.Typography.caption.weight(.medium))
            .foregroundStyle(FormaTokens.Color.textSecondary)
            .padding(.horizontal, FormaTokens.Spacing.sm)
            .padding(.vertical, FormaTokens.Spacing.xs)
            .background(
                Capsule(style: .continuous)
                    .fill(FormaTokens.Color.surface)
            )
            .overlay {
                Capsule(style: .continuous)
                    .stroke(FormaTokens.Color.border, lineWidth: 0.5)
            }
            .accessibilityLabel(accessibilityLabel)
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 12) {
        FoodEntryProvenanceBanner(source: .aiPhotoEstimate, confidence: .medium)
        FoodEntryProvenanceBanner(source: .manual, confidence: .high)
    }
    .padding()
    .background(FormaTokens.Color.canvas)
    .preferredColorScheme(.dark)
}
#endif
