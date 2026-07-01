//
//  CoachNutritionSummaryFormatter.swift
//  Fitness Coach
//
//  Coach-facing copy derived from DailyNutritionSummary (SSOT).
//

import Foundation

enum CoachNutritionSummaryFormatter {

    static func waterTodaySuffix(from nutrition: DailyNutritionSummary) -> String {
        """
        Water today:
        \(formatWater(nutrition.water.consumedMl)) / \(formatWater(nutrition.water.targetMl))ml
        \(formatWater(nutrition.water.remainingMl))ml remaining.
        """
    }

    static func waterLoggedMessage(loggedMl: Int, nutrition: DailyNutritionSummary) -> String {
        """
        Logged \(loggedMl)ml water.

        \(waterTodaySuffix(from: nutrition))
        """
    }

    static func foodLoggedSuffix(nutrition: DailyNutritionSummary) -> String {
        let proteinRemaining = max(nutrition.remaining.protein, 0)
        return """


        Today:
        \(nutrition.totals.calories) / \(nutrition.targets.calories) kcal
        \(FoodEntryFormFormatter.formatMacro(proteinRemaining))g protein remaining.
        """
    }

    static func statusMessage(from nutrition: DailyNutritionSummary) -> String {
        let remainingCalories = max(nutrition.remaining.calories, 0)
        return """
        Today so far:
        Calories: \(nutrition.totals.calories) / \(nutrition.targets.calories) kcal
        Protein: \(FoodEntryFormFormatter.formatMacro(nutrition.totals.protein)) / \(FoodEntryFormFormatter.formatMacro(nutrition.targets.protein))g
        Carbs: \(FoodEntryFormFormatter.formatMacro(nutrition.totals.carbs)) / \(FoodEntryFormFormatter.formatMacro(nutrition.targets.carbs))g
        Fat: \(FoodEntryFormFormatter.formatMacro(nutrition.totals.fat)) / \(FoodEntryFormFormatter.formatMacro(nutrition.targets.fat))g
        Water: \(nutrition.water.consumedMl) / \(nutrition.water.targetMl)ml

        You still have \(remainingCalories) kcal remaining.
        """
    }

    static func mealAdviceLines(
        nutrition: DailyNutritionSummary,
        brief: TodayDailyBrief
    ) -> [String] {
        var lines: [String] = [brief.recommendation]

        if nutrition.remaining.protein > 30 {
            lines.append(
                "You still need about \(FoodEntryFormFormatter.formatMacro(nutrition.remaining.protein))g protein today."
            )
        } else {
            lines.append(
                "Protein is on track at \(FoodEntryFormFormatter.formatMacro(nutrition.totals.protein))g of \(FoodEntryFormFormatter.formatMacro(nutrition.targets.protein))g."
            )
        }

        if nutrition.remaining.calories > 0 {
            lines.append(
                "\(nutrition.remaining.calories) kcal left — use them for nutrient-dense food, not empty snacks."
            )
        } else if nutrition.remaining.calories < 0 {
            lines.append(
                "You're \(abs(nutrition.remaining.calories)) kcal over target. Keep the next meal lean and portion-controlled."
            )
        }

        if nutrition.water.remainingMl > 400 {
            lines.append("Drink \(formatWater(nutrition.water.remainingMl))ml more water to stay on pace.")
        }

        return lines
    }

    private static func formatWater(_ ml: Int) -> String {
        PlanDisplayFormatter.formatGroupedInteger(ml)
    }
}
