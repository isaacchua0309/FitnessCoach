//
//  NutritionSuggestedActionHandler.swift
//  Fitness Coach
//
//  Forma — Maps nutrition card suggested actions to Coach behaviors.
//

import Foundation

enum NutritionSuggestedActionHandler {

    static func mealDraft(from action: NutritionSuggestedAction) -> FoodLogDraft? {
        guard action.type == .logMeal else { return nil }

        let foodName = action.payload["foodName"]?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? action.title.replacingOccurrences(of: "Log ", with: "")
        guard !foodName.isEmpty else { return nil }

        let calories = Int(action.payload["caloriesKcal"] ?? "")
        let protein = Double(action.payload["proteinGrams"] ?? "")
        let carbs = Double(action.payload["carbsGrams"] ?? "")
        let fat = Double(action.payload["fatGrams"] ?? "")
        let rangeLower = Int(action.payload["caloriesRangeLowerKcal"] ?? "")
        let rangeUpper = Int(action.payload["caloriesRangeUpperKcal"] ?? "")
        let requiresClarification = Bool(action.payload["requiresClarificationBeforeLogging"] ?? "") ?? false

        let component = FoodComponent(
            name: foodName,
            calories: calories ?? 0,
            protein: protein ?? 0,
            carbs: carbs ?? 0,
            fat: fat ?? 0,
            confidence: .medium,
            sourceText: "Nutrition estimate card",
            estimateTrustMetadata: ComponentEstimateTrustMetadata(
                componentName: foodName,
                estimatedCalories: calories ?? 0,
                rangeLower: rangeLower,
                rangeUpper: rangeUpper
            )
        )

        return FoodLogDraft(
            displayName: foodName,
            components: [component],
            confidence: .medium,
            source: .aiTextEstimate,
            notes: "Estimated from Coach nutrition card.",
            calorieRangeLower: rangeLower,
            calorieRangeUpper: rangeUpper,
            requiresClarificationBeforeLogging: requiresClarification,
            componentTrustMetadata: [component.estimateTrustMetadata].compactMap { $0 }
        )
    }

    static func mealDraft(
        from response: NutritionEstimateResponse,
        action: NutritionSuggestedAction
    ) -> FoodLogDraft? {
        guard action.type == .logMeal else { return nil }
        return CoachEstimateTrustMapper.mealDraft(from: response, action: action)
    }

    static func followUpQuery(for action: NutritionSuggestedAction) -> String? {
        switch action.type {
        case .addCommonSide:
            let side = action.payload["foodName"] ?? action.title.replacingOccurrences(of: "Add ", with: "")
            return "Estimate calories in \(side)"
        case .addDrink:
            let drink = action.payload["foodName"] ?? action.title.replacingOccurrences(of: "Add ", with: "")
            return "Estimate calories in \(drink)"
        case .compareAlternative:
            if let left = action.payload["leftFoodName"], let right = action.payload["rightFoodName"] {
                return "Compare \(left) vs \(right)"
            }
            return action.payload["query"]
        case .healthierAlternative:
            if let food = action.payload["foodName"] {
                return "What's a healthier alternative to \(food)?"
            }
            return action.payload["query"] ?? "Suggest a healthier alternative"
        case .askFollowUp:
            return action.payload["query"] ?? action.title
        case .estimateAnother, .logMeal:
            return nil
        }
    }
}
