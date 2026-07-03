//
//  NutritionEstimateContextBuilder.swift
//  Fitness Coach
//
//  Forma — Merges AI nutrition estimate with today's targets (client-side arithmetic).
//

import Foundation

enum NutritionEstimateContextBuilder {

    static func enrich(
        _ response: NutritionEstimateResponse,
        dailyLog: DailyLog?
    ) -> NutritionEstimateResponse {
        guard let dailyLog else { return response }
        var copy = response
        let nutrition = DailyNutritionSummaryBuilder.build(from: dailyLog)
        let estimateCalories = response.caloriesKcal
            ?? response.caloriesRangeUpperKcal
            ?? response.caloriesRangeLowerKcal
            ?? 0
        let estimateProtein = response.proteinGrams ?? 0

        copy.todayCaloriesTarget = nutrition.targets.calories
        copy.todayCaloriesConsumed = nutrition.totals.calories
        copy.todayCaloriesRemainingAfterEstimate = nutrition.remaining.calories - estimateCalories
        copy.todayProteinTarget = nutrition.targets.protein
        copy.todayProteinConsumed = nutrition.totals.protein
        copy.todayProteinRemainingAfterEstimate = nutrition.remaining.protein - estimateProtein
        return copy
    }

    static func todayContext(from response: NutritionEstimateResponse) -> NutritionEstimateTodayContext? {
        guard let target = response.todayCaloriesTarget,
              let consumed = response.todayCaloriesConsumed,
              let afterEstimate = response.todayCaloriesRemainingAfterEstimate,
              let proteinTarget = response.todayProteinTarget,
              let proteinConsumed = response.todayProteinConsumed else {
            return nil
        }

        let estimateCalories = response.caloriesKcal
            ?? response.caloriesRangeUpperKcal
            ?? response.caloriesRangeLowerKcal
            ?? 0
        let afterThis = consumed + estimateCalories
        let proteinAfter = proteinConsumed + (response.proteinGrams ?? 0)

        return NutritionEstimateTodayContext(
            caloriesAfterLine: "Calories after this: \(PlanDisplayFormatter.formatGroupedInteger(afterThis)) / \(PlanDisplayFormatter.formatGroupedInteger(target)) kcal",
            caloriesRemainingLine: "Remaining: \(PlanDisplayFormatter.formatGroupedInteger(max(afterEstimate, 0))) kcal",
            proteinLine: "Protein: \(FoodEntryFormFormatter.formatMacro(proteinAfter)) / \(FoodEntryFormFormatter.formatMacro(proteinTarget))g"
        )
    }
}
