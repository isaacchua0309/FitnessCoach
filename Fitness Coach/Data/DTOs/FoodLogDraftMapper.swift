//
//  FoodLogDraftMapper.swift
//  Fitness Coach
//
//  FitPilot AI — Conversions between legacy FoodDraft and multi-component FoodLogDraft.
//

import Foundation

enum FoodLogDraftMapper {

    static func fromLegacyDraft(_ draft: FoodDraft) -> FoodLogDraft {
        let component = FoodComponent(
            name: draft.name,
            quantity: draft.quantity,
            unit: draft.unit,
            calories: draft.calories,
            protein: draft.protein,
            carbs: draft.carbs,
            fat: draft.fat,
            confidence: draft.confidence,
            sourceText: draft.notes
        )
        return FoodLogDraft(
            displayName: draft.name,
            mealType: draft.mealType,
            components: [component],
            confidence: draft.confidence,
            source: draft.source,
            notes: draft.notes,
            imageUrl: draft.imageUrl
        )
    }

    static func toLegacyDraft(_ meal: FoodLogDraft) -> FoodDraft {
        FoodDraft(
            mealType: meal.mealType,
            name: meal.displayName,
            quantity: meal.legacyQuantity,
            unit: meal.legacyUnit,
            calories: meal.totalCalories,
            protein: meal.totalProtein,
            carbs: meal.totalCarbs,
            fat: meal.totalFat,
            fiber: nil,
            sodium: nil,
            source: meal.source,
            confidence: meal.confidence,
            imageUrl: meal.imageUrl,
            notes: meal.notes
        )
    }

    static func fromFoodEntry(_ entry: FoodEntry) -> FoodLogDraft {
        if let components = entry.components, !components.isEmpty {
            return FoodLogDraft(
                id: entry.id,
                displayName: entry.name,
                mealType: entry.mealType,
                components: components,
                confidence: entry.confidence,
                source: entry.source,
                notes: entry.notes,
                imageUrl: entry.imageUrl
            )
        }

        return fromLegacyDraft(
            FoodDraft(
                mealType: entry.mealType,
                name: entry.name,
                quantity: entry.quantity,
                unit: entry.unit,
                calories: entry.calories,
                protein: entry.protein,
                carbs: entry.carbs,
                fat: entry.fat,
                fiber: entry.fiber,
                sodium: entry.sodium,
                source: entry.source,
                confidence: entry.confidence,
                imageUrl: entry.imageUrl,
                notes: entry.notes
            )
        )
    }

    static func toFoodEntry(
        _ meal: FoodLogDraft,
        dailyLogId: UUID,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) -> FoodEntry {
        FoodEntry(
            id: meal.id,
            dailyLogId: dailyLogId,
            mealType: meal.mealType,
            name: meal.displayName,
            quantity: meal.legacyQuantity,
            unit: meal.legacyUnit,
            calories: meal.totalCalories,
            protein: meal.totalProtein,
            carbs: meal.totalCarbs,
            fat: meal.totalFat,
            fiber: nil,
            sodium: nil,
            source: meal.source,
            confidence: meal.confidence,
            imageUrl: meal.imageUrl,
            notes: meal.notes,
            components: meal.isMultiComponent ? meal.components : nil,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    /// Normalizes AI responses: prefers structured meal drafts, falls back to legacy food drafts.
    static func meals(from response: AIFoodEstimateResponse) -> [FoodLogDraft] {
        if !response.foodLogDrafts.isEmpty {
            return response.foodLogDrafts.map(recalculateTotals)
        }
        return response.foodDrafts.map(fromLegacyDraft)
    }

    static func primaryMeal(from response: AIFoodEstimateResponse) -> FoodLogDraft? {
        meals(from: response).first
    }

    static func recalculateTotals(_ meal: FoodLogDraft) -> FoodLogDraft {
        var normalized = meal
        guard !normalized.components.isEmpty else { return normalized }

        for index in normalized.components.indices {
            let component = normalized.components[index]
            guard component.calories >= 0,
                  component.protein >= 0,
                  component.carbs >= 0,
                  component.fat >= 0 else {
                continue
            }
            normalized.components[index] = component
        }
        return normalized
    }

    static func reconcileTotals(_ meal: FoodLogDraft) -> FoodLogDraft {
        var reconciled = recalculateTotals(meal)
        let summedCalories = reconciled.totalCalories
        let summedProtein = reconciled.totalProtein
        let summedCarbs = reconciled.totalCarbs
        let summedFat = reconciled.totalFat

        if reconciled.components.count > 1 {
            reconciled.warnings = reconciled.warnings.filter {
                !$0.hasPrefix("Totals were adjusted")
            }
        }

        if summedCalories == 0, summedProtein == 0, summedCarbs == 0, summedFat == 0 {
            reconciled.warnings.append("Missing nutrition for one or more components.")
        }

        return reconciled
    }
}
