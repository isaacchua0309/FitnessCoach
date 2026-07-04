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
        id: UUID = UUID(),
        suppressLogAction: Bool = false
    ) -> NutritionEstimateCardState {
        let sanitized = NutritionEstimateCopyValidator.sanitize(response)
        let enriched = NutritionEstimateContextBuilder.enrich(sanitized, dailyLog: dailyLog)
        let today = NutritionEstimateContextBuilder.todayContext(from: enriched)
        let trustPresentation = NutritionEstimateCardPresentationBuilder.presentation(for: enriched)

        let hasMacros = enriched.proteinGrams != nil
            || enriched.carbsGrams != nil
            || enriched.fatGrams != nil

        let suggestedActions = normalizedSuggestedActions(
            from: enriched.suggestedActions,
            response: enriched,
            suppressLogAction: suppressLogAction
        )
        let logMealAction = suggestedActions.first { $0.type == .logMeal }

        return NutritionEstimateCardState(
            id: id,
            foodName: enriched.foodName,
            displayEmoji: enriched.displayEmoji,
            servingDescription: enriched.servingDescription,
            caloriesDisplay: trustPresentation.aboutCaloriesLine,
            proteinDisplay: macroDisplay(enriched.proteinGrams, label: "Protein"),
            carbsDisplay: macroDisplay(enriched.carbsGrams, label: "Carbs"),
            fatDisplay: macroDisplay(enriched.fatGrams, label: "Fat"),
            confidenceTitle: trustPresentation.confidenceLine,
            confidenceSubtitle: enriched.confidenceReason ?? enriched.confidenceLabel,
            coachSummary: enriched.coachSummary,
            coachTip: enriched.coachTip,
            caveats: enriched.caveats,
            todayContext: today,
            suggestedActions: suggestedActions,
            sourceType: enriched.sourceType,
            confidenceLevel: enriched.confidenceLevel,
            hasMacros: hasMacros,
            hasTodayContext: today != nil,
            logMealPayload: logMealAction,
            calorieRange: NutritionEstimateCardPresentationBuilder.calorieRange(for: enriched),
            estimateTrust: NutritionEstimateCardPresentationBuilder.estimateTrust(for: enriched),
            trustPresentation: trustPresentation,
            sourceResponse: enriched,
            allowsLogging: !suppressLogAction
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
        if let trust = state.trustPresentation {
            var parts = [state.displayEmoji, state.foodName, trust.accessibilityLabel]
                .compactMap { $0 }
            if let serving = state.servingDescription { parts.insert(serving, at: 2) }
            return parts.joined(separator: ". ")
        }

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

    private static func normalizedSuggestedActions(
        from actions: [NutritionSuggestedAction],
        response: NutritionEstimateResponse,
        suppressLogAction: Bool
    ) -> [NutritionSuggestedAction] {
        actions.compactMap { action in
            guard action.type == .logMeal else { return action }
            guard !suppressLogAction else { return nil }
            return enrichedLogMealAction(action, response: response)
        }
    }

    private static func enrichedLogMealAction(
        _ action: NutritionSuggestedAction,
        response: NutritionEstimateResponse
    ) -> NutritionSuggestedAction {
        var payload = action.payload
        payload["foodName"] = payload["foodName"] ?? response.foodName
        if let calories = response.caloriesKcal {
            payload["caloriesKcal"] = String(calories)
        }
        if let protein = response.proteinGrams {
            payload["proteinGrams"] = String(protein)
        }
        if let carbs = response.carbsGrams {
            payload["carbsGrams"] = String(carbs)
        }
        if let fat = response.fatGrams {
            payload["fatGrams"] = String(fat)
        }
        if let lower = response.caloriesRangeLowerKcal {
            payload["caloriesRangeLowerKcal"] = String(lower)
        }
        if let upper = response.caloriesRangeUpperKcal {
            payload["caloriesRangeUpperKcal"] = String(upper)
        }
        if response.requiresClarificationBeforeLogging {
            payload["requiresClarificationBeforeLogging"] = "true"
        }

        return NutritionSuggestedAction(
            id: action.id,
            title: FormaProductCopy.Coach.logEstimatePending,
            type: .logMeal,
            payload: payload
        )
    }

    private static func itemCaloriesDisplay(_ item: NutritionComparisonItem) -> String {
        if let kcal = item.caloriesKcal {
            return FormaProductCopy.Coach.estimateCardAboutCalories(about: kcal)
        }
        if let lower = item.caloriesRangeLowerKcal, let upper = item.caloriesRangeUpperKcal {
            return FormaProductCopy.Coach.pendingLikelyRange(lower: lower, upper: upper)
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
}
