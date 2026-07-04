//
//  FoodEstimateTrustNormalizer.swift
//  Fitness Coach
//
//  Forma — Repairs and enriches Coach food estimate trust metadata.
//

import Foundation

enum FoodEstimateTrustNormalizer {

    private static let hiddenSauceOilPattern = try! NSRegularExpression(
        pattern: #"\b(sauce|oil|dressing|mayo|mayonnaise|gravy|butter|sambal|chili|creamy|fried|hidden sauce|hidden oil|cooking oil)\b"#,
        options: [.caseInsensitive]
    )

    private static let sauceOilUncertaintyHint = "Hidden sauce or cooking oil amount is uncertain."
    private static let lowConfidenceUncertaintyHint = "Portion size is unclear."

    static func normalize(_ meal: FoodLogDraft, prompt: String? = nil) -> FoodLogDraft {
        var normalized = meal
        normalized.assumptions = uniqueNonEmpty(normalized.assumptions)
        if normalized.assumptions.isEmpty {
            normalized.assumptions = CoachEstimateTrustMapper.assumptions(from: normalized.warnings)
        }

        let nonAssumptionWarnings = CoachEstimateTrustMapper.nonAssumptionWarnings(from: normalized.warnings)
        if nonAssumptionWarnings.count != normalized.warnings.count {
            normalized.warnings = nonAssumptionWarnings
        }

        let rangeResolution = FoodCalorieRangeResolver.resolve(
            totalCalories: normalized.totalCalories,
            confidence: normalized.confidence,
            lower: normalized.calorieRangeLower,
            upper: normalized.calorieRangeUpper
        )
        normalized.calorieRangeLower = rangeResolution.lower
        normalized.calorieRangeUpper = rangeResolution.upper

        if let warning = rangeResolution.warning {
            normalized.warnings.append(warning)
            if rangeResolution.source == .repaired,
               rangeResolution.lower == 0,
               rangeResolution.upper == 0,
               normalized.totalCalories > 0 {
                normalized.confidence = downgradedConfidence(normalized.confidence)
            }
        }

        normalized.uncertaintyReasons = uniqueNonEmpty(normalized.uncertaintyReasons)
        if normalized.confidence == .low, normalized.uncertaintyReasons.isEmpty {
            normalized.uncertaintyReasons.append(lowConfidenceUncertaintyHint)
        }

        if likelyHiddenSauceOrOil(meal: normalized, prompt: prompt),
           !normalized.uncertaintyReasons.contains(where: mentionsSauceOrOil) {
            normalized.uncertaintyReasons.append(sauceOilUncertaintyHint)
        }

        normalized.suggestedClarifications = uniqueNonEmpty(normalized.suggestedClarifications)
        normalized.primaryUncertainty = normalized.primaryUncertainty?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
            ?? normalized.uncertaintyReasons.first

        if normalized.riskLevel == nil {
            normalized.riskLevel = riskLevel(for: normalized.confidence)
        }

        if normalized.requiresClarificationBeforeLogging == false {
            normalized.requiresClarificationBeforeLogging =
                normalized.confidence == .low
                || !normalized.suggestedClarifications.isEmpty
                || normalized.uncertaintyReasons.contains(where: mentionsPortionOrSauceAmbiguity)
        }

        normalized.components = normalized.components.map { normalizeComponent($0, mealConfidence: normalized.confidence) }
        normalized.componentTrustMetadata = syncComponentTrustMetadata(for: normalized)
        return normalized
    }

    static func normalize(response: AIFoodEstimateResponse, prompt: String?) -> AIFoodEstimateResponse {
        var copy = response
        copy.foodLogDrafts = response.foodLogDrafts.map { normalize($0, prompt: prompt) }
        copy.foodDrafts = copy.foodLogDrafts.map(FoodLogDraftMapper.toLegacyDraft)
        return copy
    }

    static func normalize(_ response: AIMealImageAnalysisResponse) -> AIMealImageAnalysisResponse {
        var copy = response
        let draft = FoodEstimateTrustNormalizer.normalize(MealImageAnalysisMapper.buildFoodLogDraft(from: response))
        let normalizedDraft = normalize(draft)

        copy.total.calorieRangeLower = normalizedDraft.calorieRangeLower
        copy.total.calorieRangeUpper = normalizedDraft.calorieRangeUpper
        copy.primaryUncertainty = normalizedDraft.primaryUncertainty
        copy.needsUserReview = normalizedDraft.requiresClarificationBeforeLogging || response.needsUserReview

        copy.items = zip(copy.items, normalizedDraft.components).map { item, component in
            var updated = item
            if let metadata = component.estimateTrustMetadata {
                updated.calorieRangeLower = metadata.rangeLower
                updated.calorieRangeUpper = metadata.rangeUpper
                updated.assumptions = metadata.assumptions
                updated.uncertaintyReasons = metadata.uncertaintyReasons
                updated.primaryUncertainty = metadata.uncertaintyReasons.first
            }
            return updated
        }

        return copy
    }

    // MARK: - Private

    private static func normalizeComponent(
        _ component: FoodComponent,
        mealConfidence: ConfidenceLevel
    ) -> FoodComponent {
        var updated = component
        let confidence = component.confidence
        let existingLower = component.estimateTrustMetadata?.rangeLower
        let existingUpper = component.estimateTrustMetadata?.rangeUpper

        let rangeResolution = FoodCalorieRangeResolver.resolve(
            totalCalories: component.calories,
            confidence: confidence,
            lower: existingLower,
            upper: existingUpper
        )

        var metadata = component.estimateTrustMetadata ?? ComponentEstimateTrustMetadata(
            componentName: component.name,
            estimatedCalories: component.calories
        )
        metadata.rangeLower = rangeResolution.lower
        metadata.rangeUpper = rangeResolution.upper
        metadata.assumptions = uniqueNonEmpty(metadata.assumptions)
        metadata.uncertaintyReasons = uniqueNonEmpty(metadata.uncertaintyReasons)

        if confidence == .low, metadata.uncertaintyReasons.isEmpty {
            metadata.uncertaintyReasons.append(lowConfidenceUncertaintyHint)
        }

        if likelyHiddenSauceOrOil(text: component.name) || likelyHiddenSauceOrOil(text: component.sourceText),
           !metadata.uncertaintyReasons.contains(where: mentionsSauceOrOil) {
            metadata.uncertaintyReasons.append(sauceOilUncertaintyHint)
        }

        if mealConfidence == .low, updated.confidence == .high {
            updated.confidence = .medium
        }

        updated.estimateTrustMetadata = metadata
        return updated
    }

    private static func syncComponentTrustMetadata(for meal: FoodLogDraft) -> [ComponentEstimateTrustMetadata] {
        if !meal.componentTrustMetadata.isEmpty {
            return meal.componentTrustMetadata
        }
        return meal.components.compactMap(\.estimateTrustMetadata)
    }

    private static func likelyHiddenSauceOrOil(meal: FoodLogDraft, prompt: String?) -> Bool {
        if likelyHiddenSauceOrOil(text: prompt) { return true }
        if meal.components.contains(where: {
            likelyHiddenSauceOrOil(text: $0.name) || likelyHiddenSauceOrOil(text: $0.sourceText)
        }) {
            return true
        }
        return meal.assumptions.contains(where: likelyHiddenSauceOrOil(text:))
    }

    private static func likelyHiddenSauceOrOil(text: String?) -> Bool {
        guard let text else { return false }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        return hiddenSauceOilPattern.firstMatch(in: trimmed, range: range) != nil
    }

    private static func mentionsSauceOrOil(_ reason: String) -> Bool {
        let lowered = reason.lowercased()
        return lowered.contains("sauce") || lowered.contains("oil") || lowered.contains("dressing")
    }

    private static func mentionsPortionOrSauceAmbiguity(_ reason: String) -> Bool {
        let lowered = reason.lowercased()
        return lowered.contains("portion")
            || lowered.contains("sauce")
            || lowered.contains("oil")
            || lowered.contains("unclear")
            || lowered.contains("ambiguous")
    }

    private static func downgradedConfidence(_ confidence: ConfidenceLevel) -> ConfidenceLevel {
        switch confidence {
        case .high: return .medium
        case .medium, .low: return .low
        }
    }

    private static func riskLevel(for confidence: ConfidenceLevel) -> EstimateRiskLevel {
        switch confidence {
        case .high: return .low
        case .medium: return .medium
        case .low: return .high
        }
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

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
