//
//  NutritionEstimateCardPresentation.swift
//  Fitness Coach
//
//  Forma — Trust-aware display model for nutrition estimate cards.
//

import Foundation

struct NutritionEstimateCardPresentation: Codable, Equatable, Sendable {
    var aboutCaloriesLine: String
    var likelyRangeLine: String?
    var confidenceLine: String
    var assumptionLines: [String]
    var hiddenAssumptionCount: Int
    var biggestUncertaintyLine: String?
    var accuracyHintLine: String?
    var lowConfidenceWarning: String?
    var accessibilityLabel: String

    static let maxVisibleAssumptions = 3
}

enum NutritionEstimateCardPresentationBuilder {

    static func presentation(for response: NutritionEstimateResponse) -> NutritionEstimateCardPresentation {
        let calories = resolvedCalories(for: response)
        let aboutLine = aboutCaloriesLine(for: calories)
        let rangeLine = likelyRangeLine(for: response, calories: calories)
        let confidence = confidenceLine(for: response.confidenceLevel)
        let assumptions = visibleAssumptions(for: response)
        let hiddenAssumptions = max(0, allAssumptions(for: response).count - NutritionEstimateCardPresentation.maxVisibleAssumptions)
        let biggestUncertainty = biggestUncertaintyLine(for: response)
        let accuracyHint = accuracyHintLine(for: response)
        let lowWarning = lowConfidenceWarning(for: response.confidenceLevel)

        var accessibilityParts = [
            response.foodName,
            aboutLine,
            confidence
        ]
        if let rangeLine { accessibilityParts.append(rangeLine) }
        if let biggestUncertainty { accessibilityParts.append(biggestUncertainty) }
        if let accuracyHint { accessibilityParts.append(accuracyHint) }
        if let lowWarning { accessibilityParts.append(lowWarning) }
        accessibilityParts.append(contentsOf: assumptions)

        return NutritionEstimateCardPresentation(
            aboutCaloriesLine: aboutLine,
            likelyRangeLine: rangeLine,
            confidenceLine: confidence,
            assumptionLines: assumptions,
            hiddenAssumptionCount: hiddenAssumptions,
            biggestUncertaintyLine: biggestUncertainty,
            accuracyHintLine: accuracyHint,
            lowConfidenceWarning: lowWarning,
            accessibilityLabel: accessibilityParts.joined(separator: ". ")
        )
    }

    static func calorieRange(for response: NutritionEstimateResponse) -> CalorieEstimateRange? {
        let calories = resolvedCalories(for: response)
        let resolution = FoodCalorieRangeResolver.resolve(
            totalCalories: calories,
            confidence: confidenceLevel(from: response.confidenceLevel),
            lower: response.caloriesRangeLowerKcal,
            upper: response.caloriesRangeUpperKcal
        )
        guard calories > 0 || resolution.upper > 0 else { return nil }
        return CalorieEstimateRange(
            estimated: max(calories, (resolution.lower + resolution.upper) / 2),
            lowerBound: resolution.lower,
            upperBound: resolution.upper,
            source: .nutritionEstimateCard
        )
    }

    static func estimateTrust(for response: NutritionEstimateResponse) -> CoachEstimateTrustMetadata {
        CoachEstimateTrustMetadata(
            confidence: confidenceLevel(from: response.confidenceLevel),
            assumptions: allAssumptions(for: response),
            uncertaintyReasons: uniqueNonEmpty(response.uncertaintyReasons + response.caveats),
            suggestedClarifications: uniqueNonEmpty(response.suggestedClarifications),
            requiresClarificationBeforeLogging: response.requiresClarificationBeforeLogging
                || response.confidenceLevel == .low
                || !response.suggestedClarifications.isEmpty,
            primaryUncertainty: response.primaryUncertainty ?? response.confidenceReason,
            riskLevel: response.riskLevel
        )
    }

    // MARK: - Private

    private static func resolvedCalories(for response: NutritionEstimateResponse) -> Int {
        response.caloriesKcal
            ?? midpoint(
                lower: response.caloriesRangeLowerKcal,
                upper: response.caloriesRangeUpperKcal
            )
            ?? 0
    }

    private static func aboutCaloriesLine(for calories: Int) -> String {
        guard calories > 0 else {
            return "Calories unavailable"
        }
        return FormaProductCopy.Coach.estimateCardAboutCalories(about: calories)
    }

    private static func likelyRangeLine(
        for response: NutritionEstimateResponse,
        calories: Int
    ) -> String? {
        guard let range = calorieRange(for: response),
              range.hasBounds,
              let lower = range.lowerBound,
              let upper = range.upperBound else {
            return nil
        }
        return FormaProductCopy.Coach.pendingLikelyRange(lower: lower, upper: upper)
    }

    private static func confidenceLine(for confidence: AIConfidence) -> String {
        FormaProductCopy.Coach.pendingConfidence(
            label: AIFoodConfirmationFormatter.shortConfidenceLabel(confidence)
        )
    }

    private static func biggestUncertaintyLine(for response: NutritionEstimateResponse) -> String? {
        if let primary = response.primaryUncertainty?.trimmingCharacters(in: .whitespacesAndNewlines),
           !primary.isEmpty {
            return FormaProductCopy.Coach.pendingMainUncertainty(primary)
        }
        if let reason = response.uncertaintyReasons.first?.trimmingCharacters(in: .whitespacesAndNewlines),
           !reason.isEmpty {
            return FormaProductCopy.Coach.pendingMainUncertainty(reason)
        }
        return nil
    }

    private static func accuracyHintLine(for response: NutritionEstimateResponse) -> String? {
        if let clarification = response.suggestedClarifications.first?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !clarification.isEmpty {
            return clarification
        }
        if let uncertainty = response.primaryUncertainty?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !uncertainty.isEmpty {
            return "Share whether \(uncertainty.lowercased()) was different."
        }
        return FormaProductCopy.Coach.pendingTellCoachGenericHint
    }

    private static func lowConfidenceWarning(for confidence: AIConfidence) -> String? {
        guard confidence == .low else { return nil }
        return FormaProductCopy.Coach.pendingLowConfidenceWarning
    }

    private static func allAssumptions(for response: NutritionEstimateResponse) -> [String] {
        let structured = response.assumptions
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if !structured.isEmpty {
            return uniqueNonEmpty(structured)
        }
        return uniqueNonEmpty(response.caveats)
    }

    private static func visibleAssumptions(for response: NutritionEstimateResponse) -> [String] {
        Array(allAssumptions(for: response).prefix(NutritionEstimateCardPresentation.maxVisibleAssumptions))
    }

    private static func confidenceLevel(from confidence: AIConfidence) -> ConfidenceLevel {
        switch confidence {
        case .high: return .high
        case .medium: return .medium
        case .low: return .low
        }
    }

    private static func midpoint(lower: Int?, upper: Int?) -> Int? {
        guard let lower, let upper, lower <= upper else { return nil }
        return (lower + upper) / 2
    }

    private static func uniqueNonEmpty(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.compactMap { value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            let key = trimmed.lowercased()
            guard !seen.contains(key) else { return nil }
            seen.insert(key)
            return trimmed
        }
    }
}
