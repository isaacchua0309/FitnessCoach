//
//  MealImageAnalysisTrustPolicy.swift
//  Fitness Coach
//
//  Normalizes meal-photo trust metadata and detects low-confidence scenarios.
//

import Foundation

enum MealPhotoTrustScenario: String, Equatable, Sendable, CaseIterable {
    case croppedPlate
    case multiplePlates
    case poorLighting
    case hiddenSauces
    case buffet
    case manySmallDishes
    case ambiguousDrinkSize
    case unclearPortionSize
}

struct MealImageAnalysisTrustMetadata: Equatable, Sendable {
    var confidence: AIConfidence
    var assumptions: [String]
    var uncertaintyReasons: [String]
    var suggestedClarifications: [String]
    var primaryUncertainty: String?
    var calorieRangeLower: Int
    var calorieRangeUpper: Int
    var needsUserReview: Bool
    var clarifyingQuestion: String?
    var detectedScenarios: [MealPhotoTrustScenario]
    var presentationWarnings: [String]
}

enum MealImageAnalysisTrustPolicy {

    static let photoReviewRequiredMessage = "Please review before logging."
    static let estimatedFromPhotoMessage = "I estimated this from the photo."
    static let croppedPlateWarning =
        "The plate looks cropped or partially out of frame — portions may be incomplete."
    static let multiplePlatesQuestion =
        "I see more than one plate. Which plate should I log unless you meant all of them?"

    private static let scenarioPatterns: [(MealPhotoTrustScenario, [String])] = [
        (.croppedPlate, ["cropped", "cut off", "partial plate", "out of frame", "edge of plate"]),
        (.multiplePlates, ["multiple plate", "several plate", "two plate", "both plate", "all plates visible"]),
        (.poorLighting, ["poor lighting", "dark photo", "low light", "blurry", "unclear photo"]),
        (.hiddenSauces, ["hidden sauce", "hidden oil", "sauce not visible", "dressing not visible", "oil not visible"]),
        (.buffet, ["buffet", "self-serve", "mixed spread", "many dishes"]),
        (.manySmallDishes, ["many small dish", "multiple small dish", "several side", "assorted side"]),
        (.ambiguousDrinkSize, ["drink size unclear", "cup size unclear", "bottle size unclear", "ambiguous drink"]),
        (.unclearPortionSize, ["portion unclear", "portion size unclear", "amount unclear", "serving size unclear"]),
    ]

    static func normalize(
        response: AIMealImageAnalysisResponse,
        userCaption: String = ""
    ) -> (response: AIMealImageAnalysisResponse, metadata: MealImageAnalysisTrustMetadata) {
        let overallConfidence = overallConfidence(from: response.items)
        let detectedScenarios = detectScenarios(in: response, userCaption: userCaption)
        var assumptions = uniqueStrings(response.items.flatMap(\.assumptions))
        var uncertaintyReasons = uniqueStrings(
            response.items.flatMap(\.uncertaintyReasons) +
            (response.primaryUncertainty.map { [$0] } ?? [])
        )
        var suggestedClarifications = uniqueStrings(response.items.flatMap(\.suggestedClarifications))
        var clarifyingQuestion = trimmed(response.clarifyingQuestion)
        var presentationWarnings: [String] = []

        applyScenarioAdjustments(
            scenarios: detectedScenarios,
            assumptions: &assumptions,
            uncertaintyReasons: &uncertaintyReasons,
            suggestedClarifications: &suggestedClarifications,
            clarifyingQuestion: &clarifyingQuestion,
            presentationWarnings: &presentationWarnings,
            userCaption: userCaption
        )

        let primaryUncertainty = trimmed(response.primaryUncertainty)
            ?? uncertaintyReasons.first
            ?? clarifyingQuestion

        let adjustedConfidence = capPhotoConfidence(
            adjustedConfidence(
                base: overallConfidence,
                scenarios: detectedScenarios
            )
        )

        if assumptions.isEmpty {
            assumptions.append(defaultAssumption(for: adjustedConfidence))
        }
        if uncertaintyReasons.isEmpty {
            uncertaintyReasons.append(defaultUncertainty(for: adjustedConfidence))
        }

        let calorieRange = resolveTotalRange(
            response: response,
            confidence: adjustedConfidence
        )

        if adjustedConfidence == .low, clarifyingQuestion == nil, suggestedClarifications.isEmpty {
            suggestedClarifications.append(
                primaryUncertainty.map { "Can you clarify \($0.lowercased())?" } ??
                    "Can you clarify portion size or hidden sauce/oil?"
            )
        }

        var normalizedItems = response.items
        for index in normalizedItems.indices {
            if normalizedItems[index].uncertaintyReasons.isEmpty, adjustedConfidence != .high {
                normalizedItems[index].uncertaintyReasons = [defaultUncertainty(for: normalizedItems[index].confidence)]
            }
            if normalizedItems[index].assumptions.isEmpty {
                normalizedItems[index].assumptions = [defaultAssumption(for: normalizedItems[index].confidence)]
            }
            let itemRange = FoodCalorieRangePolicy.resolve(
                calories: normalizedItems[index].calories,
                confidence: normalizedItems[index].confidence,
                explicitLower: normalizedItems[index].calorieRangeLower,
                explicitUpper: normalizedItems[index].calorieRangeUpper
            )
            normalizedItems[index].calorieRangeLower = itemRange.lower
            normalizedItems[index].calorieRangeUpper = itemRange.upper
        }

        let normalizedTotal = AIMealImageAnalysisTotals(
            calories: response.total.calories,
            protein: response.total.protein,
            carbs: response.total.carbs,
            fat: response.total.fat,
            calorieRangeLower: calorieRange.lower,
            calorieRangeUpper: calorieRange.upper
        )

        let normalizedResponse = AIMealImageAnalysisResponse(
            summary: response.summary,
            items: normalizedItems,
            total: normalizedTotal,
            needsUserReview: true,
            clarifyingQuestion: clarifyingQuestion,
            primaryUncertainty: primaryUncertainty,
            usage: response.usage
        )

        let metadata = MealImageAnalysisTrustMetadata(
            confidence: adjustedConfidence,
            assumptions: assumptions,
            uncertaintyReasons: uncertaintyReasons,
            suggestedClarifications: suggestedClarifications,
            primaryUncertainty: primaryUncertainty,
            calorieRangeLower: calorieRange.lower,
            calorieRangeUpper: calorieRange.upper,
            needsUserReview: true,
            clarifyingQuestion: clarifyingQuestion,
            detectedScenarios: detectedScenarios,
            presentationWarnings: presentationWarnings
        )

        return (normalizedResponse, metadata)
    }

    static func captionLogsAllPlates(_ caption: String) -> Bool {
        let lower = caption.lowercased()
        let markers = [
            "all plates", "both plates", "every plate", "whole table",
            "everything", "all of them", "log all", "all dishes"
        ]
        return markers.contains(where: { lower.contains($0) })
    }

    static func detectScenarios(
        in response: AIMealImageAnalysisResponse,
        userCaption: String = ""
    ) -> [MealPhotoTrustScenario] {
        let haystack = combinedText(response: response, userCaption: userCaption)
        var detected = scenarioPatterns.compactMap { scenario, patterns in
            patterns.contains(where: { haystack.contains($0) }) ? scenario : nil
        }

        if response.items.count >= 4, !detected.contains(.manySmallDishes) {
            detected.append(.manySmallDishes)
        }
        if haystack.contains("buffet"), !detected.contains(.buffet) {
            detected.append(.buffet)
        }
        if looksLikeMultiplePlates(in: haystack), !detected.contains(.multiplePlates) {
            detected.append(.multiplePlates)
        }
        if haystack.contains("sauce") || haystack.contains("dressing") || haystack.contains("oil"),
           !detected.contains(.hiddenSauces) {
            let hasSauceItem = response.items.contains {
                let name = $0.name.lowercased()
                return name.contains("sauce") || name.contains("dressing") || name.contains("oil")
            }
            if !hasSauceItem {
                detected.append(.hiddenSauces)
            }
        }

        return Array(Set(detected)).sorted { $0.rawValue < $1.rawValue }
    }

    // MARK: - Private

    private static func applyScenarioAdjustments(
        scenarios: [MealPhotoTrustScenario],
        assumptions: inout [String],
        uncertaintyReasons: inout [String],
        suggestedClarifications: inout [String],
        clarifyingQuestion: inout String?,
        presentationWarnings: inout [String],
        userCaption: String
    ) {
        if scenarios.contains(.croppedPlate) {
            presentationWarnings.append(croppedPlateWarning)
            uncertaintyReasons.append("Plate appears cropped or partially out of frame.")
            if clarifyingQuestion == nil {
                clarifyingQuestion = "Is any food missing because the plate is cropped?"
            }
        }

        if scenarios.contains(.multiplePlates), !captionLogsAllPlates(userCaption) {
            presentationWarnings.append(multiplePlatesQuestion)
            uncertaintyReasons.append("Multiple plates are visible in the photo.")
            if clarifyingQuestion == nil {
                clarifyingQuestion = multiplePlatesQuestion
            }
            suggestedClarifications.append("Which plate should I log?")
        }

        if scenarios.contains(.hiddenSauces) {
            uncertaintyReasons.append("Hidden oil or sauce may not be fully visible.")
            assumptions.append("Assumed standard cooking oil/sauce where not visible.")
        }

        if scenarios.contains(.poorLighting) {
            uncertaintyReasons.append("Lighting or focus makes some details hard to see.")
        }
        if scenarios.contains(.buffet) || scenarios.contains(.manySmallDishes) {
            uncertaintyReasons.append("Multiple dishes make exact portions harder to estimate.")
        }
        if scenarios.contains(.ambiguousDrinkSize) {
            uncertaintyReasons.append("Drink cup or bottle size is unclear.")
        }
        if scenarios.contains(.unclearPortionSize) {
            uncertaintyReasons.append("Portion size is unclear from the photo.")
        }
    }

    private static func capPhotoConfidence(_ confidence: AIConfidence) -> AIConfidence {
        switch confidence {
        case .high:
            return .medium
        case .medium, .low:
            return confidence
        }
    }

    private static func adjustedConfidence(
        base: AIConfidence,
        scenarios: [MealPhotoTrustScenario]
    ) -> AIConfidence {
        let lowConfidenceScenarios: Set<MealPhotoTrustScenario> = [
            .croppedPlate, .multiplePlates, .poorLighting, .hiddenSauces,
            .buffet, .manySmallDishes, .ambiguousDrinkSize, .unclearPortionSize
        ]
        guard scenarios.contains(where: { lowConfidenceScenarios.contains($0) }) else {
            return base == .high ? .medium : base
        }
        switch base {
        case .high:
            return .medium
        case .medium, .low:
            return .low
        }
    }

    private static func resolveTotalRange(
        response: AIMealImageAnalysisResponse,
        confidence: AIConfidence
    ) -> FoodCalorieRange {
        let resolved = FoodCalorieRangePolicy.resolve(
            calories: response.total.calories,
            confidence: confidence,
            explicitLower: response.total.calorieRangeLower,
            explicitUpper: response.total.calorieRangeUpper
        )
        if confidence == .low || !response.items.flatMap(\.uncertaintyReasons).isEmpty {
            return FoodCalorieRangePolicy.widenForUncertainty(
                calories: response.total.calories,
                confidence: confidence,
                lower: resolved.lower,
                upper: resolved.upper,
                upwardBias: confidence == .low ? 60 : 30
            )
        }
        return resolved
    }

    private static func overallConfidence(from items: [AIMealImageAnalysisItem]) -> AIConfidence {
        let levels = items.map(\.confidence)
        if levels.contains(.low) { return .low }
        if levels.allSatisfy({ $0 == .high }) { return .high }
        return .medium
    }

    private static func combinedText(response: AIMealImageAnalysisResponse, userCaption: String) -> String {
        [
            response.summary,
            userCaption,
            response.primaryUncertainty,
            response.clarifyingQuestion,
            response.items.flatMap(\.assumptions).joined(separator: " "),
            response.items.flatMap(\.uncertaintyReasons).joined(separator: " "),
            response.items.map(\.name).joined(separator: " ")
        ]
        .compactMap { $0?.lowercased() }
        .joined(separator: " ")
    }

    private static func looksLikeMultiplePlates(in text: String) -> Bool {
        text.contains("multiple plate") ||
            text.contains("several plate") ||
            text.contains("two plate") ||
            text.contains("both plate") ||
            text.contains("two bowls") ||
            text.contains("both bowls")
    }

    private static func defaultAssumption(for confidence: AIConfidence) -> String {
        switch confidence {
        case .low:
            return "Portion size and some ingredients were estimated from limited photo detail."
        case .medium:
            return "Some portion or preparation details were assumed from the photo."
        case .high:
            return "Minor preparation details were assumed from the photo."
        }
    }

    private static func defaultUncertainty(for confidence: AIConfidence) -> String {
        switch confidence {
        case .low:
            return "Portion size or hidden ingredients are unclear from the photo."
        case .medium:
            return "Some portion or sauce details were uncertain in the photo."
        case .high:
            return "Minor preparation details were uncertain in the photo."
        }
    }

    private static func trimmed(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func uniqueStrings(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for value in values {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = trimmed.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(trimmed)
        }
        return result
    }
}
