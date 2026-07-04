//
//  CoachEstimateTrustMapper.swift
//  Fitness Coach
//
//  Forma — Maps transport and analysis payloads into FoodLogDraft trust fields.
//

import Foundation

enum CoachEstimateTrustMapper {

    // MARK: - Meal image

    static func enrich(
        _ draft: FoodLogDraft,
        from response: AIMealImageAnalysisResponse
    ) -> FoodLogDraft {
        let itemAssumptions = response.items
            .flatMap(\.assumptions)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var uncertaintyReasons: [String] = []
        if response.needsUserReview {
            uncertaintyReasons.append("Photo estimate needs review before logging.")
        }

        var suggestedClarifications: [String] = []
        if let question = response.clarifyingQuestion?.trimmingCharacters(in: .whitespacesAndNewlines),
           !question.isEmpty {
            suggestedClarifications.append(question)
        }
        suggestedClarifications.append(contentsOf: response.items.flatMap(\.suggestedClarifications).map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty })

        let componentMetadata = zip(draft.components, response.items).map { component, item in
            componentTrustMetadata(for: component, item: item)
        }

        let confidence = confidenceLevel(from: response)
        var enriched = draft
        enriched.confidence = confidence
        enriched.assumptions = uniqueNonEmpty(itemAssumptions)
        enriched.uncertaintyReasons = uniqueNonEmpty(uncertaintyReasons)
        enriched.suggestedClarifications = uniqueNonEmpty(suggestedClarifications)
        enriched.primaryUncertainty = response.primaryUncertainty?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? response.items.compactMap(\.primaryUncertainty).first?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        enriched.requiresClarificationBeforeLogging = response.needsUserReview
            || !suggestedClarifications.isEmpty
            || confidence == .low
        enriched.riskLevel = riskLevel(for: confidence)
        enriched.componentTrustMetadata = componentMetadata
        enriched.calorieRangeLower = response.total.calorieRangeLower ?? enriched.calorieRangeLower
        enriched.calorieRangeUpper = response.total.calorieRangeUpper ?? enriched.calorieRangeUpper
        enriched.components = zip(enriched.components, response.items).map { component, item in
            var updated = component
            updated.estimateTrustMetadata = componentTrustMetadata(for: component, item: item)
            return updated
        }
        return enriched
    }

    // MARK: - Nutrition estimate card

    static func mealDraft(
        from response: NutritionEstimateResponse,
        action: NutritionSuggestedAction
    ) -> FoodLogDraft {
        let foodName = action.payload["foodName"]?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? response.foodName
        let calories = Int(action.payload["caloriesKcal"] ?? "") ?? response.caloriesKcal ?? 0
        let protein = Double(action.payload["proteinGrams"] ?? "") ?? response.proteinGrams ?? 0
        let carbs = Double(action.payload["carbsGrams"] ?? "") ?? response.carbsGrams ?? 0
        let fat = Double(action.payload["fatGrams"] ?? "") ?? response.fatGrams ?? 0
        let rangeLower = Int(action.payload["caloriesRangeLowerKcal"] ?? "") ?? response.caloriesRangeLowerKcal
        let rangeUpper = Int(action.payload["caloriesRangeUpperKcal"] ?? "") ?? response.caloriesRangeUpperKcal

        let confidence = response.confidenceLevel.asConfidenceLevel
        let assumptions = response.assumptions
        let uncertaintyReasons = response.uncertaintyReasons + response.caveats
        let suggestedClarifications = response.suggestedClarifications

        let component = FoodComponent(
            name: foodName,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            confidence: confidence,
            sourceText: "Nutrition estimate card",
            estimateTrustMetadata: ComponentEstimateTrustMetadata(
                componentName: foodName,
                estimatedCalories: calories,
                rangeLower: rangeLower,
                rangeUpper: rangeUpper,
                assumptions: assumptions,
                uncertaintyReasons: uncertaintyReasons
            )
        )

        return FoodLogDraft(
            displayName: foodName,
            components: [component],
            confidence: confidence,
            source: .aiTextEstimate,
            notes: "Estimated from Coach nutrition card.",
            calorieRangeLower: rangeLower,
            calorieRangeUpper: rangeUpper,
            assumptions: assumptions,
            uncertaintyReasons: uniqueNonEmpty(uncertaintyReasons),
            suggestedClarifications: uniqueNonEmpty(suggestedClarifications),
            primaryUncertainty: response.primaryUncertainty ?? response.confidenceReason,
            requiresClarificationBeforeLogging: response.requiresClarificationBeforeLogging
                || confidence == .low
                || !suggestedClarifications.isEmpty,
            riskLevel: response.riskLevel ?? riskLevel(for: confidence),
            componentTrustMetadata: [component.estimateTrustMetadata].compactMap { $0 }
        )
    }

    // MARK: - Warnings / assumptions normalization

    static func assumptions(from warnings: [String]) -> [String] {
        warnings.compactMap { warning in
            let trimmed = warning.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            if trimmed.lowercased().hasPrefix("assumption:") {
                return String(trimmed.dropFirst("assumption:".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return nil
        }
    }

    static func nonAssumptionWarnings(from warnings: [String]) -> [String] {
        warnings.filter { warning in
            !warning.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().hasPrefix("assumption:")
        }
    }

    // MARK: - Private

    private static func confidenceLevel(from response: AIMealImageAnalysisResponse) -> ConfidenceLevel {
        let levels = response.items.map(\.confidence)
        if levels.contains(.low) { return .low }
        if levels.allSatisfy({ $0 == .high }) { return .high }
        return .medium
    }

    private static func componentTrustMetadata(
        for component: FoodComponent,
        item: AIMealImageAnalysisItem
    ) -> ComponentEstimateTrustMetadata {
        ComponentEstimateTrustMetadata(
            componentName: component.name,
            estimatedCalories: component.calories,
            rangeLower: item.calorieRangeLower,
            rangeUpper: item.calorieRangeUpper,
            assumptions: item.assumptions,
            uncertaintyReasons: item.uncertaintyReasons
        )
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

private extension AIConfidence {
    var asConfidenceLevel: ConfidenceLevel {
        switch self {
        case .high: return .high
        case .medium: return .medium
        case .low: return .low
        }
    }
}
