//
//  NutritionEstimateCardFormatter.swift
//  Fitness Coach
//
//  Forma — Maps transport models to nutrition estimate card display state.
//

import Foundation

enum NutritionEstimateCardFormatter {

    static func cardState(
        from response: NutritionEstimateResponse,
        dailyLog: DailyLog?,
        id: UUID = UUID()
    ) -> NutritionEstimateCardState {
        let sanitized = NutritionEstimateCopyValidator.sanitize(response)
        let enriched = NutritionEstimateContextBuilder.enrich(sanitized, dailyLog: dailyLog)
        let today = NutritionEstimateContextBuilder.todayContext(from: enriched)

        let hasMacros = enriched.proteinGrams != nil
            || enriched.carbsGrams != nil
            || enriched.fatGrams != nil

        let logMealAction = enriched.suggestedActions.first { $0.type == .logMeal }

        return NutritionEstimateCardState(
            id: id,
            foodName: enriched.foodName,
            displayEmoji: enriched.displayEmoji,
            servingDescription: enriched.servingDescription,
            caloriesDisplay: caloriesDisplay(for: enriched),
            proteinDisplay: macroDisplay(enriched.proteinGrams, label: "Protein"),
            carbsDisplay: macroDisplay(enriched.carbsGrams, label: "Carbs"),
            fatDisplay: macroDisplay(enriched.fatGrams, label: "Fat"),
            confidenceTitle: confidenceTitle(for: enriched),
            confidenceSubtitle: enriched.confidenceReason ?? enriched.confidenceLabel,
            coachSummary: enriched.coachSummary,
            coachTip: enriched.coachTip,
            caveats: enriched.caveats,
            todayContext: today,
            suggestedActions: enriched.suggestedActions,
            sourceType: enriched.sourceType,
            confidenceLevel: enriched.confidenceLevel,
            hasMacros: hasMacros,
            hasTodayContext: today != nil,
            logMealPayload: logMealAction
        )
    }

    static func comparisonCardState(
        from response: NutritionComparisonResponse,
        id: UUID = UUID()
    ) -> NutritionComparisonCardState {
        let sanitized = NutritionEstimateCopyValidator.sanitizeComparison(response)
        return NutritionComparisonCardState(
            id: id,
            leftItem: sanitized.leftItem,
            rightItem: sanitized.rightItem,
            leftCaloriesDisplay: itemCaloriesDisplay(sanitized.leftItem),
            rightCaloriesDisplay: itemCaloriesDisplay(sanitized.rightItem),
            leftProteinDisplay: itemMacroDisplay(sanitized.leftItem.proteinGrams),
            rightProteinDisplay: itemMacroDisplay(sanitized.rightItem.proteinGrams),
            leftFatDisplay: itemFatDisplay(sanitized.leftItem.fatGrams),
            rightFatDisplay: itemFatDisplay(sanitized.rightItem.fatGrams),
            coachPick: sanitized.coachPick,
            suggestedActions: sanitized.suggestedActions
        )
    }

    static func accessibilitySummary(for state: NutritionEstimateCardState) -> String {
        var parts = [state.displayEmoji, state.foodName, state.caloriesDisplay]
            .compactMap { $0 }
        if let serving = state.servingDescription { parts.append(serving) }
        if let tip = state.coachTip { parts.append(tip) }
        return parts.joined(separator: ". ")
    }

    static func accessibilitySummary(for state: NutritionComparisonCardState) -> String {
        var parts = [
            "\(state.leftItem.foodName): \(state.leftCaloriesDisplay)",
            "\(state.rightItem.foodName): \(state.rightCaloriesDisplay)"
        ]
        if let pick = state.coachPick { parts.append(pick) }
        return parts.joined(separator: ". ")
    }

    // MARK: - Private

    private static func caloriesDisplay(for response: NutritionEstimateResponse) -> String {
        if let kcal = response.caloriesKcal {
            return "\(PlanDisplayFormatter.formatGroupedInteger(kcal)) kcal"
        }
        if let lower = response.caloriesRangeLowerKcal,
           let upper = response.caloriesRangeUpperKcal {
            return "\(PlanDisplayFormatter.formatGroupedInteger(lower))–\(PlanDisplayFormatter.formatGroupedInteger(upper)) kcal"
        }
        return "Estimated kcal"
    }

    private static func itemCaloriesDisplay(_ item: NutritionComparisonItem) -> String {
        if let kcal = item.caloriesKcal {
            return "\(PlanDisplayFormatter.formatGroupedInteger(kcal)) kcal"
        }
        if let lower = item.caloriesRangeLowerKcal, let upper = item.caloriesRangeUpperKcal {
            return "\(PlanDisplayFormatter.formatGroupedInteger(lower))–\(PlanDisplayFormatter.formatGroupedInteger(upper)) kcal"
        }
        return "— kcal"
    }

    private static func macroDisplay(_ grams: Double?, label: String) -> String? {
        guard let grams else { return nil }
        return "\(label) \(FoodEntryFormFormatter.formatMacro(grams))g"
    }

    private static func itemMacroDisplay(_ grams: Double?) -> String? {
        guard let grams else { return nil }
        return "\(FoodEntryFormFormatter.formatMacro(grams))g protein"
    }

    private static func itemFatDisplay(_ grams: Double?) -> String? {
        guard let grams else { return nil }
        return "\(FoodEntryFormFormatter.formatMacro(grams))g fat"
    }

    private static func confidenceTitle(for response: NutritionEstimateResponse) -> String {
        if let label = response.confidenceLabel, !label.isEmpty {
            return label.lowercased().contains("confidence") ? label : "\(label) confidence"
        }
        switch response.confidenceLevel {
        case .high: return "High confidence"
        case .medium: return "Medium confidence"
        case .low: return "Low confidence"
        }
    }
}
