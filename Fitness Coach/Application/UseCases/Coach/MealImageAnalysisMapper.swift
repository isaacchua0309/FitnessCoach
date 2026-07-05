//
//  MealImageAnalysisMapper.swift
//  Fitness Coach
//
//  Maps dedicated meal-image analysis API payloads to Coach food drafts.
//

import Foundation

enum MealImageAnalysisMapper {

    static func sessionResult(
        from response: AIMealImageAnalysisResponse,
        userCaption: String = ""
    ) -> ImageAnalysisSessionResult {
        let normalized = MealImageAnalysisTrustPolicy.normalize(
            response: response,
            userCaption: userCaption
        )
        let mealDraft = foodLogDraft(
            from: normalized.response,
            trust: normalized.metadata
        )
        return ImageAnalysisSessionResult(
            mealDraft: mealDraft,
            confidence: normalized.metadata.confidence,
            summary: normalized.response.summary,
            clarifyingQuestion: normalized.metadata.clarifyingQuestion,
            trust: normalized.metadata
        )
    }

    static func foodLogDraft(
        from response: AIMealImageAnalysisResponse,
        userCaption: String = ""
    ) -> FoodLogDraft {
        let normalized = MealImageAnalysisTrustPolicy.normalize(
            response: response,
            userCaption: userCaption
        )
        return foodLogDraft(from: normalized.response, trust: normalized.metadata)
    }

    static func previousAnalysis(
        from result: ImageAnalysisSessionResult
    ) -> AIMealImageAnalysisPreviousAnalysis {
        AIMealImageAnalysisPreviousAnalysis(
            summary: result.summary,
            items: result.mealDraft.components.map { component in
                AIMealImageAnalysisPreviousItem(
                    name: component.name,
                    quantity: portionLabel(for: component),
                    calories: component.calories,
                    protein: component.protein,
                    carbs: component.carbs,
                    fat: component.fat,
                    confidence: aiConfidence(from: component.confidence),
                    assumptions: [component.sourceText].compactMap { $0 }.filter { !$0.isEmpty },
                    uncertaintyReasons: result.mealDraft.uncertaintyReasons,
                    primaryUncertainty: result.mealDraft.primaryUncertainty,
                    calorieRangeLower: nil,
                    calorieRangeUpper: nil
                )
            },
            total: AIMealImageAnalysisTotals(
                calories: result.mealDraft.totalCalories,
                protein: result.mealDraft.totalProtein,
                carbs: result.mealDraft.totalCarbs,
                fat: result.mealDraft.totalFat,
                calorieRangeLower: result.trust?.calorieRangeLower ?? result.mealDraft.calorieRangeLower,
                calorieRangeUpper: result.trust?.calorieRangeUpper ?? result.mealDraft.calorieRangeUpper
            ),
            primaryUncertainty: result.trust?.primaryUncertainty ?? result.mealDraft.primaryUncertainty,
            calorieRangeLower: result.trust?.calorieRangeLower ?? result.mealDraft.calorieRangeLower,
            calorieRangeUpper: result.trust?.calorieRangeUpper ?? result.mealDraft.calorieRangeUpper
        )
    }

    // MARK: - Private

    private static func foodLogDraft(
        from response: AIMealImageAnalysisResponse,
        trust: MealImageAnalysisTrustMetadata
    ) -> FoodLogDraft {
        let components = response.items.map { item in
            let quantityValue = parseLeadingNumber(from: item.quantity)
            return FoodComponent(
                name: item.name,
                quantity: quantityValue,
                unit: parseUnit(from: item.quantity),
                calories: item.calories,
                protein: item.protein,
                carbs: item.carbs,
                fat: item.fat,
                confidence: confidenceLevel(from: item.confidence),
                sourceText: item.assumptions.joined(separator: "; ")
            )
        }

        var warnings = uniqueStrings(
            trust.presentationWarnings +
            [MealImageAnalysisTrustPolicy.photoReviewRequiredMessage]
        )
        if let clarifyingQuestion = trust.clarifyingQuestion {
            warnings.append(clarifyingQuestion)
        }

        return FoodLogDraft(
            displayName: displayName(for: response),
            components: components,
            confidence: confidenceLevel(from: trust.confidence),
            source: .aiPhotoEstimate,
            notes: response.summary,
            warnings: warnings,
            assumptions: trust.assumptions,
            uncertaintyReasons: trust.uncertaintyReasons,
            suggestedClarifications: trust.suggestedClarifications,
            primaryUncertainty: trust.primaryUncertainty,
            requiresClarificationBeforeLogging: trust.confidence == .low || trust.clarifyingQuestion != nil,
            calorieRangeLower: trust.calorieRangeLower,
            calorieRangeUpper: trust.calorieRangeUpper
        )
    }

    private static func displayName(for response: AIMealImageAnalysisResponse) -> String {
        let trimmed = response.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        if response.items.count == 1 {
            return response.items[0].name
        }
        return "Meal photo"
    }

    private static func confidenceLevel(from confidence: AIConfidence) -> ConfidenceLevel {
        switch confidence {
        case .high: return .high
        case .medium: return .medium
        case .low: return .low
        }
    }

    private static func aiConfidence(from confidence: ConfidenceLevel) -> AIConfidence {
        switch confidence {
        case .high: return .high
        case .medium: return .medium
        case .low: return .low
        }
    }

    private static func portionLabel(for component: FoodComponent) -> String? {
        let quantity = component.quantity.map(FoodEntryFormFormatter.formatOptionalDouble) ?? ""
        let unit = component.unit ?? ""
        let joined = [quantity, unit].filter { !$0.isEmpty }.joined(separator: " ")
        return joined.isEmpty ? nil : joined
    }

    private static func parseLeadingNumber(from quantity: String?) -> Double? {
        guard let quantity else { return nil }
        let parts = quantity.split(separator: " ")
        guard let first = parts.first else { return nil }
        return Double(first)
    }

    private static func parseUnit(from quantity: String?) -> String? {
        guard let quantity else { return nil }
        let parts = quantity.split(separator: " ")
        guard parts.count > 1 else { return nil }
        return parts.dropFirst().joined(separator: " ")
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
        return result.sorted()
    }
}
