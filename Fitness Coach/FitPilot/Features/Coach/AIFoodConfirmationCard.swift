//
//  AIFoodConfirmationCard.swift
//  Fitness Coach
//
//  FitPilot AI — Inline banner for a pending AI food estimate.
//

import SwiftUI

struct AIFoodConfirmationCard: View {
    let draft: AIFoodConfirmationDraft
    let onReview: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "fork.knife.circle")
                .font(.title2)
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 6) {
                Text(FormaProductCopy.Coach.foodEstimatePending)
                    .font(.subheadline.weight(.semibold))

                if let foodDraft = draft.primaryFoodDraft {
                    Text("\(foodDraft.name) • \(foodDraft.calories) kcal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button(FormaProductCopy.Coach.reviewEstimate) {
                    onReview()
                }
                .font(.subheadline.weight(.medium))
            }

            Spacer(minLength: 0)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .padding(.top, 8)
    }
}

#Preview {
    AIFoodConfirmationCard(
        draft: AIFoodConfirmationDraft(
            originalText: "log chicken rice",
            assistantMessage: nil,
            foodDrafts: [
                FoodDraft(
                    mealType: nil,
                    name: "Chicken rice",
                    quantity: 1,
                    unit: "plate",
                    calories: 650,
                    protein: 35,
                    carbs: 75,
                    fat: 20,
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
        ),
        onReview: {}
    )
}
