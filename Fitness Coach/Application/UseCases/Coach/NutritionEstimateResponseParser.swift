//
//  NutritionEstimateResponseParser.swift
//  Fitness Coach
//
//  Forma — Parses structured nutrition estimate/comparison responses with safe fallbacks.
//

import Foundation

enum NutritionEstimateParseOutcome: Equatable {
    case estimate(NutritionEstimateCardState)
    case comparison(NutritionComparisonCardState)
    case plainText(String)
}

enum NutritionEstimateResponseParser {

    static func parseEstimate(
        _ response: NutritionEstimateResponse,
        dailyLog: DailyLog?,
        prompt: String? = nil,
        parseFailedHandler: (() -> Void)? = nil
    ) -> NutritionEstimateParseOutcome {
        let suppressLogAction = prompt.map(CoachIntentPhraseGuard.isEstimateOnlyWithoutLogging) ?? false
        let card = NutritionEstimateCardFormatter.cardState(
            from: response,
            dailyLog: dailyLog,
            suppressLogAction: suppressLogAction
        )
        guard !card.foodName.isEmpty else {
            parseFailedHandler?()
            return .plainText("Could not estimate that food. Try a more specific name.")
        }
        return .estimate(card)
    }

    static func parseComparison(
        _ response: NutritionComparisonResponse,
        parseFailedHandler: (() -> Void)? = nil
    ) -> NutritionEstimateParseOutcome {
        let card = NutritionEstimateCardFormatter.comparisonCardState(from: response)
        guard !card.leftItem.foodName.isEmpty, !card.rightItem.foodName.isEmpty else {
            parseFailedHandler?()
            return .plainText("Could not compare those foods. Try naming both items clearly.")
        }
        return .comparison(card)
    }

    static func parseEstimateFallback(
        from rawText: String,
        prompt: String,
        dailyLog: DailyLog?,
        parseFailedHandler: (() -> Void)? = nil
    ) -> NutritionEstimateParseOutcome {
        parseFailedHandler?()

        if let extracted = extractEstimate(from: rawText, prompt: prompt) {
            return parseEstimate(extracted, dailyLog: dailyLog, prompt: prompt)
        }

        let compact = NutritionEstimateCopyValidator.compactFallbackLines(from: rawText)
        if compact.isEmpty {
            return .plainText("Could not estimate that food. Try a more specific name.")
        }
        return .plainText(compact)
    }

    static func parseComparisonFallback(
        from rawText: String,
        parseFailedHandler: (() -> Void)? = nil
    ) -> NutritionEstimateParseOutcome {
        parseFailedHandler?()
        let compact = NutritionEstimateCopyValidator.compactFallbackLines(from: rawText)
        if compact.isEmpty {
            return .plainText("Could not compare those foods. Try naming both items clearly.")
        }
        return .plainText(compact)
    }

    // MARK: - Heuristic extraction

    private static func extractEstimate(
        from text: String,
        prompt: String
    ) -> NutritionEstimateResponse? {
        let calories = extractCalories(from: text)
        guard calories.single != nil || calories.range != nil else { return nil }

        let foodName = extractFoodName(from: prompt) ?? "Food"
        var response = NutritionEstimateResponse(
            foodName: foodName,
            caloriesKcal: calories.single,
            caloriesRangeLowerKcal: calories.range?.lower,
            caloriesRangeUpperKcal: calories.range?.upper,
            proteinGrams: extractMacro(from: text, labels: ["protein"]),
            carbsGrams: extractMacro(from: text, labels: ["carbs", "carbohydrates"]),
            fatGrams: extractMacro(from: text, labels: ["fat"]),
            confidenceLevel: .low,
            confidenceLabel: "Low",
            confidenceReason: "Extracted from unstructured response.",
            coachSummary: nil,
            coachTip: nil,
            suggestedActions: defaultEstimateActions(foodName: foodName, calories: calories)
        )
        response = NutritionEstimateCopyValidator.sanitize(response)
        return response
    }

    private static func extractCalories(from text: String) -> (single: Int?, range: (lower: Int, upper: Int)?) {
        let rangePattern = #"(\d{2,4})\s*[–-]\s*(\d{2,4})\s*kcal"#
        if let match = text.range(of: rangePattern, options: [.regularExpression, .caseInsensitive]) {
            let snippet = String(text[match])
            let numbers = snippet.components(separatedBy: CharacterSet.decimalDigits.inverted)
                .compactMap { Int($0) }
            if numbers.count >= 2 {
                return (nil, (min(numbers[0], numbers[1]), max(numbers[0], numbers[1])))
            }
        }

        let singlePattern = #"(\d{2,4})\s*kcal"#
        if let match = text.range(of: singlePattern, options: [.regularExpression, .caseInsensitive]) {
            let snippet = String(text[match])
            if let number = snippet.components(separatedBy: CharacterSet.decimalDigits.inverted)
                .compactMap({ Int($0) }).first {
                return (number, nil)
            }
        }

        return (nil, nil)
    }

    private static func extractMacro(from text: String, labels: [String]) -> Double? {
        for label in labels {
            let pattern = #"\b\#(label)\b[^0-9]*(\d+(?:\.\d+)?)\s*g"#
            if let match = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                let snippet = String(text[match])
                if let value = snippet.components(separatedBy: CharacterSet.decimalDigits.inverted.union(CharacterSet(charactersIn: ".")))
                    .compactMap({ Double($0) }).last {
                    return value
                }
            }
        }
        return nil
    }

    private static func extractFoodName(from prompt: String) -> String? {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let patterns = [
            #"calories in (?:a |an )?(.+)$"#,
            #"estimate (?:the )?calories in (?:a |an )?(.+)$"#,
            #"how many calories (?:does |in )?(?:a |an )?(.+?)(?:\?|$)"#,
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
               let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: trimmed) {
                let name = String(trimmed[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty { return name.capitalized }
            }
        }
        return trimmed
    }

    private static func defaultEstimateActions(
        foodName: String,
        calories: (single: Int?, range: (lower: Int, upper: Int)?)
    ) -> [NutritionSuggestedAction] {
        var payload: [String: String] = ["foodName": foodName]
        if let kcal = calories.single {
            payload["caloriesKcal"] = String(kcal)
        }
        return [
            NutritionSuggestedAction(title: "Log \(foodName)", type: .logMeal, payload: payload),
            NutritionSuggestedAction(title: "Estimate another food", type: .estimateAnother)
        ]
    }
}
