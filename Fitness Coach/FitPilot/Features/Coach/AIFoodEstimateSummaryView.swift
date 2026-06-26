//
//  AIFoodEstimateSummaryView.swift
//  Fitness Coach
//
//  FitPilot AI — Read-only summary of an AI food estimate.
//

import SwiftUI

struct AIFoodEstimateSummaryView: View {
    let draft: AIFoodConfirmationDraft

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.md) {
                summaryRow(label: "You said", value: draft.originalText)

                if let foodDraft = draft.primaryFoodDraft {
                    summaryRow(label: "Food", value: foodDraft.name)

                    if foodDraft.hasUsableNutritionEstimate {
                        nutritionHero(for: foodDraft)
                        summaryRow(
                            label: "Macros",
                            value: AIFoodConfirmationFormatter.macroSummary(for: foodDraft)
                        )
                    } else {
                        Text("Nutrition estimate is still loading. Edit the fields below if needed.")
                            .font(FormaTokens.Typography.caption)
                            .foregroundStyle(FormaTokens.Color.textSecondary)
                    }

                    summaryRow(
                        label: "Confidence",
                        value: AIFoodConfirmationFormatter.confidenceLabel(draft.confidence)
                    )
                }

                if let assistantMessage = draft.assistantMessage,
                   !assistantMessage.isEmpty,
                   !assistantMessage.lowercased().contains("requires confirmation") {
                    Text(assistantMessage)
                        .font(FormaTokens.Typography.caption)
                        .foregroundStyle(FormaTokens.Color.textSecondary)
                }

                Text(AIFoodConfirmationFormatter.confirmationWarning(confidence: draft.confidence))
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(FormaTokens.Color.textTertiary)
            }
            .padding(.vertical, FormaTokens.Spacing.xs)
        } header: {
            FitPilotSettingsSectionHeader(title: "Estimate")
        }
    }

    private func nutritionHero(for foodDraft: FoodDraft) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("\(foodDraft.calories)")
                .font(FormaTokens.Typography.screenTitle)
                .foregroundStyle(FormaTokens.Color.textPrimary)
            Text("kcal")
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(FormaTokens.Color.textSecondary)
        }
    }

    private func summaryRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(FormaTokens.Color.textSecondary)
            Text(value)
                .font(FormaTokens.Typography.body)
                .foregroundStyle(FormaTokens.Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    Form {
        AIFoodEstimateSummaryView(
            draft: AIFoodConfirmationDraft(
                originalText: "log mcspicy meal with fries",
                assistantMessage: nil,
                foodDrafts: [
                    FoodDraft(
                        mealType: nil,
                        name: "McSpicy meal with large fries",
                        quantity: 1,
                        unit: "meal",
                        calories: 980,
                        protein: 38,
                        carbs: 95,
                        fat: 48,
                        fiber: nil,
                        sodium: nil,
                        source: .aiTextEstimate,
                        confidence: .medium,
                        imageUrl: nil,
                        notes: nil
                    )
                ],
                confidence: .medium,
                requiresConfirmation: true
            )
        )
    }
}
