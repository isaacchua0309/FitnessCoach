//
//  MealImageAnalysisMapper.swift
//  Fitness Coach
//
//  Maps dedicated meal-image analysis API payloads to Coach food drafts.
//

import Foundation

enum MealImageAnalysisMapper {

    static func sessionResult(
        from response: AIMealImageAnalysisResponse
    ) -> ImageAnalysisSessionResult {
        let mealDraft = foodLogDraft(from: response)
        let confidence = overallConfidence(from: response)
        return ImageAnalysisSessionResult(
            mealDraft: mealDraft,
            confidence: confidence,
            summary: response.summary,
            clarifyingQuestion: response.clarifyingQuestion
        )
    }

    static func foodLogDraft(from response: AIMealImageAnalysisResponse) -> FoodLogDraft {
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

        var warnings: [String] = []
        if response.needsUserReview {
            warnings.append("Review this photo estimate before logging.")
        }
        if let clarifyingQuestion = response.clarifyingQuestion?.trimmingCharacters(in: .whitespacesAndNewlines),
           !clarifyingQuestion.isEmpty {
            warnings.append(clarifyingQuestion)
        }
        let assumptionLines = response.items
            .flatMap(\.assumptions)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        warnings.append(contentsOf: assumptionLines.prefix(4))

        return FoodLogDraft(
            displayName: displayName(for: response),
            components: components,
            confidence: confidenceLevel(from: overallConfidence(from: response)),
            source: .aiPhotoEstimate,
            notes: response.summary,
            warnings: warnings
        )
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
                    assumptions: [component.sourceText].compactMap { $0 }.filter { !$0.isEmpty }
                )
            },
            total: AIMealImageAnalysisTotals(
                calories: result.mealDraft.totalCalories,
                protein: result.mealDraft.totalProtein,
                carbs: result.mealDraft.totalCarbs,
                fat: result.mealDraft.totalFat
            )
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

    private static func overallConfidence(from response: AIMealImageAnalysisResponse) -> AIConfidence {
        let levels = response.items.map(\.confidence)
        if levels.contains(.low) { return .low }
        if levels.allSatisfy({ $0 == .high }) { return .high }
        return .medium
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
}
