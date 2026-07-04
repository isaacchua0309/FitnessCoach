//
//  FoodCorrectionMemoryApplier.swift
//  Fitness Coach
//
//  Forma — Applies correction memory hints to food estimates when safe.
//

import Foundation

struct FoodCorrectionMemoryApplication: Equatable, Sendable {
    var mealDraft: FoodLogDraft
    var appliedSummaries: [String]
}

enum FoodCorrectionMemoryApplier {

    static func apply(
        to meal: FoodLogDraft,
        corrections: [CoachFoodCorrectionContext],
        prompt: String? = nil
    ) -> FoodCorrectionMemoryApplication {
        guard !corrections.isEmpty else {
            return FoodCorrectionMemoryApplication(mealDraft: meal, appliedSummaries: [])
        }

        let foodKey = CoachContextFoodMemoryBuilder.normalizedFoodName(meal.displayName)
        let promptKey = prompt.map(CoachContextFoodMemoryBuilder.normalizedFoodName) ?? ""
        let relevant = corrections.filter { correction in
            guard let key = correction.foodKey, !key.isEmpty else { return false }
            return foodKey.contains(key) || key.contains(foodKey) || (!promptKey.isEmpty && promptKey.contains(key))
        }

        guard !relevant.isEmpty else {
            return FoodCorrectionMemoryApplication(mealDraft: meal, appliedSummaries: [])
        }

        var updated = meal
        var summaries: [String] = []
        var assumptions = updated.assumptions

        for correction in relevant.prefix(3) {
            let summary = correction.patternSummary.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !summary.isEmpty else { continue }

            let assumption = "Correction hint: \(summary)"
            if !assumptions.contains(where: { $0.caseInsensitiveCompare(assumption) == .orderedSame }) {
                assumptions.append(assumption)
            }

            if let applied = applySafeComponentAdjustment(
                to: &updated,
                correction: correction
            ) {
                summaries.append("Using your recent correction: \(applied).")
            } else {
                summaries.append("Using your recent correction: \(displayHint(for: correction)).")
            }
        }

        updated.assumptions = uniquePreservingOrder(assumptions)
        return FoodCorrectionMemoryApplication(mealDraft: updated, appliedSummaries: uniquePreservingOrder(summaries))
    }

    // MARK: - Private

    private static func applySafeComponentAdjustment(
        to meal: inout FoodLogDraft,
        correction: CoachFoodCorrectionContext
    ) -> String? {
        guard correction.correctionType == FoodCorrectionType.portionAdjustment.rawValue
            || correction.correctionType == FoodCorrectionType.sauceOrOilAdjustment.rawValue
            || correction.correctionType == FoodCorrectionType.componentAdded.rawValue else {
            return nil
        }

        guard let componentName = correction.componentName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !componentName.isEmpty else {
            return displayHint(for: correction)
        }

        if let amountHint = correction.amountHint?.trimmingCharacters(in: .whitespacesAndNewlines),
           !amountHint.isEmpty,
           !containsExactGrams(amountHint) {
            if let index = meal.components.firstIndex(where: {
                CoachContextFoodMemoryBuilder.normalizedFoodName($0.name)
                    .contains(CoachContextFoodMemoryBuilder.normalizedFoodName(componentName))
            }) {
                var component = meal.components[index]
                component.sourceText = "Correction hint: \(amountHint)"
                meal.components[index] = component
                return "\(componentName) often \(amountHint)"
            }
            return "\(componentName) often \(amountHint)"
        }

        return displayHint(for: correction)
    }

    private static func displayHint(for correction: CoachFoodCorrectionContext) -> String {
        if let component = correction.componentName, !component.isEmpty,
           let amount = correction.amountHint, !amount.isEmpty {
            return "\(component) often \(amount)"
        }
        return correction.patternSummary
            .replacingOccurrences(of: "User corrected ", with: "")
            .replacingOccurrences(of: "User often adds ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func containsExactGrams(_ text: String) -> Bool {
        text.range(of: #"\d+\s*g\b"#, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private static func uniquePreservingOrder(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { value in
            let key = value.lowercased()
            guard !seen.contains(key) else { return false }
            seen.insert(key)
            return true
        }
    }
}
