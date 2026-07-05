//
//  MealImageAnalysisResponseValidator.swift
//  Fitness Coach
//
//  Validates structured meal-image analysis before creating a draft card.
//

import Foundation

enum MealImageAnalysisValidationResult: Equatable, Sendable {
    case valid
    case invalid([String])

    var isValid: Bool {
        if case .valid = self { return true }
        return false
    }

    var errors: [String] {
        if case .invalid(let errors) = self { return errors }
        return []
    }
}

enum MealImageAnalysisResponseValidator {

    private static let calorieTolerance = 3.0
    private static let macroTolerance = 1.0

    private static let genericFoodNamePattern = try! NSRegularExpression(
        pattern: #"\b(unknown|generic|unidentified|mysterious|miscellaneous|various|mixed meal|food item|meal item|something|stuff|snack plate)\b"#,
        options: [.caseInsensitive]
    )

    static func validate(
        response: AIMealImageAnalysisResponse,
        userCaption: String = ""
    ) -> MealImageAnalysisValidationResult {
        var errors: [String] = []

        let summary = response.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        if summary.isEmpty {
            errors.append("summary is required.")
        }

        if !response.needsUserReview {
            errors.append("needsUserReview must be true for photo estimates.")
        }

        if response.items.isEmpty {
            errors.append("items must contain at least one identified food.")
            return .invalid(errors)
        }

        for (index, item) in response.items.enumerated() {
            let name = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if name.isEmpty {
                errors.append("items[\(index)].name is required.")
                continue
            }
            if isGenericFoodName(name) {
                errors.append("items[\(index)].name is too generic: \"\(name)\".")
            }
            if item.calories < 0 || item.protein < 0 || item.carbs < 0 || item.fat < 0 {
                errors.append("items[\(index)] macros must be non-negative.")
            }
            if item.assumptions.isEmpty {
                errors.append("items[\(index)] must include assumptions.")
            }
            if item.confidence == .low, item.assumptions.isEmpty {
                errors.append("items[\(index)] must include assumptions when confidence is low.")
            }
            if let lower = item.calorieRangeLower, let upper = item.calorieRangeUpper {
                if !FoodCalorieRangePolicy.isWideEnough(
                    calories: item.calories,
                    lower: lower,
                    upper: upper,
                    confidence: item.confidence
                ) {
                    errors.append("items[\(index)] calorie range is too narrow for \(item.confidence.rawValue) confidence.")
                }
            }
        }

        let summed = sumItems(response.items)
        if !withinTolerance(actual: Double(response.total.calories), expected: summed.calories, absolute: calorieTolerance) {
            errors.append("total.calories does not match item sums.")
        }
        if !withinTolerance(actual: response.total.protein, expected: summed.protein, absolute: macroTolerance) {
            errors.append("total.protein does not match item sums.")
        }
        if !withinTolerance(actual: response.total.carbs, expected: summed.carbs, absolute: macroTolerance) {
            errors.append("total.carbs does not match item sums.")
        }
        if !withinTolerance(actual: response.total.fat, expected: summed.fat, absolute: macroTolerance) {
            errors.append("total.fat does not match item sums.")
        }

        let normalized = MealImageAnalysisTrustPolicy.normalize(
            response: response,
            userCaption: userCaption
        )
        let confidence = normalized.metadata.confidence

        if response.needsUserReview, confidence == .high {
            errors.append("needsUserReview responses must not claim high confidence.")
        }

        if normalized.metadata.uncertaintyReasons.isEmpty, confidence != .high {
            errors.append("Photo estimates must include uncertainty reasons when confidence is not high.")
        }

        if normalized.metadata.primaryUncertainty?.isEmpty ?? true, confidence == .low {
            errors.append("Low-confidence photo estimates must include primaryUncertainty.")
        }

        if !FoodCalorieRangePolicy.isWideEnough(
            calories: response.total.calories,
            lower: normalized.metadata.calorieRangeLower,
            upper: normalized.metadata.calorieRangeUpper,
            confidence: confidence
        ) {
            errors.append("total calorie range is too narrow for \(confidence.rawValue) confidence.")
        }

        if normalized.metadata.detectedScenarios.contains(.multiplePlates),
           !MealImageAnalysisTrustPolicy.captionLogsAllPlates(userCaption),
           normalized.metadata.clarifyingQuestion == nil,
           normalized.metadata.suggestedClarifications.isEmpty {
            errors.append("Multiple plates require clarifyingQuestion or suggestedClarifications unless the caption logs all plates.")
        }

        let mealDraft = MealImageAnalysisMapper.foodLogDraft(
            from: normalized.response,
            userCaption: userCaption
        )

        switch AIResponseValidator.validateFood(
            mealDraft,
            confidence: ConfirmationPolicy.presentationConfidence(for: mealDraft)
        ) {
        case .invalid(let message):
            errors.append(message)
        case .valid, .requiresConfirmation:
            break
        }

        return errors.isEmpty ? .valid : .invalid(errors)
    }

    // MARK: - Private

    private static func isGenericFoodName(_ name: String) -> Bool {
        let range = NSRange(name.startIndex..<name.endIndex, in: name)
        return genericFoodNamePattern.firstMatch(in: name, range: range) != nil
    }

    private static func sumItems(
        _ items: [AIMealImageAnalysisItem]
    ) -> (calories: Double, protein: Double, carbs: Double, fat: Double) {
        items.reduce((0, 0, 0, 0)) { partial, item in
            (
                partial.0 + Double(item.calories),
                partial.1 + item.protein,
                partial.2 + item.carbs,
                partial.3 + item.fat
            )
        }
    }

    private static func withinTolerance(actual: Double, expected: Double, absolute: Double) -> Bool {
        abs(actual - expected) <= absolute
    }
}
