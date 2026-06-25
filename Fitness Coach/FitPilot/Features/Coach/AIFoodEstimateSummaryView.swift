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
        Section("Estimate") {
            LabeledContent("You said") {
                Text(draft.originalText)
                    .multilineTextAlignment(.trailing)
            }

            if let foodDraft = draft.primaryFoodDraft {
                LabeledContent("Food") {
                    Text(foodDraft.name)
                }
                LabeledContent("Calories") {
                    Text("\(foodDraft.calories) kcal")
                }
                LabeledContent("Macros") {
                    Text(AIFoodConfirmationFormatter.macroSummary(for: foodDraft))
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Confidence") {
                    Text(AIFoodConfirmationFormatter.confidenceLabel(draft.confidence))
                }
                LabeledContent("Source") {
                    Text(AIFoodConfirmationFormatter.sourceLabel(foodDraft.source))
                }
            }

            if let assistantMessage = draft.assistantMessage, !assistantMessage.isEmpty {
                Text(assistantMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text(AIFoodConfirmationFormatter.confirmationWarning(confidence: draft.confidence))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    Form {
        AIFoodEstimateSummaryView(
            draft: AIFoodConfirmationDraft(
                originalText: "log 3 scoops ON whey",
                assistantMessage: "I read this as 3 scoops of whey protein.",
                foodDrafts: [
                    FoodDraft(
                        mealType: nil,
                        name: "ON whey protein",
                        quantity: 3,
                        unit: "scoops",
                        calories: 360,
                        protein: 72,
                        carbs: 9,
                        fat: 4.5,
                        fiber: nil,
                        sodium: nil,
                        source: .aiTextEstimate,
                        confidence: .high,
                        imageUrl: nil,
                        notes: nil
                    )
                ],
                confidence: .high,
                requiresConfirmation: true
            )
        )
    }
}
