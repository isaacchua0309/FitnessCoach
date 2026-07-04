//
//  CoachPendingFoodEstimatePresentation.swift
//  Fitness Coach
//
//  Forma — Trust-aware display model for pending food confirmation UI.
//

import Foundation

struct CoachPendingFoodEstimatePresentation: Equatable, Sendable {
    var mealName: String
    var estimatedCaloriesLine: String
    var likelyRangeLine: String?
    var confidenceLine: String
    var mainUncertaintyLine: String?
    var lowConfidenceWarning: String?
    var assumptionLines: [String]
    var hiddenAssumptionCount: Int
    var componentLines: [String]
    var hiddenComponentCount: Int
    var editHintLine: String
    var correctionHintLine: String?
    var sourceLine: String?
    var sanityWarning: String?
    var accessibilityLabel: String

    static let maxVisibleAssumptions = 3
    static let maxVisibleComponents = 4
}

enum CoachPendingFoodEstimatePresentationBuilder {

    static func presentation(for draft: AIFoodConfirmationDraft) -> CoachPendingFoodEstimatePresentation {
        let meal = draft.primaryMealDraft
        let calories = meal.totalCalories
        let estimatedLine = estimatedCaloriesLine(for: calories)
        let rangeLine = likelyRangeLine(for: meal)
        let confidenceLine = confidenceLine(for: draft.confidence)
        let mainUncertainty = mainUncertaintyLine(for: meal)
        let assumptions = visibleAssumptions(for: meal)
        let hiddenAssumptions = max(0, allAssumptions(for: meal).count - CoachPendingFoodEstimatePresentation.maxVisibleAssumptions)
        let components = visibleComponentLines(for: meal)
        let hiddenComponents = max(0, meal.components.count - CoachPendingFoodEstimatePresentation.maxVisibleComponents)
        let lowWarning = lowConfidenceWarning(confidence: draft.confidence)
        let sourceLine = AIFoodConfirmationFormatter.pendingSourceLabel(
            sourceAttribution: draft.sourceAttribution,
            foodSource: meal.source
        )
        let correctionHint = correctionHintLine(for: meal)

        var accessibilityParts = [
            meal.displayName,
            estimatedLine,
            confidenceLine
        ]
        if let rangeLine { accessibilityParts.append(rangeLine) }
        if let mainUncertainty { accessibilityParts.append(mainUncertainty) }
        if let lowWarning { accessibilityParts.append(lowWarning) }

        return CoachPendingFoodEstimatePresentation(
            mealName: meal.displayName,
            estimatedCaloriesLine: estimatedLine,
            likelyRangeLine: rangeLine,
            confidenceLine: confidenceLine,
            mainUncertaintyLine: mainUncertainty,
            lowConfidenceWarning: lowWarning,
            assumptionLines: assumptions,
            hiddenAssumptionCount: hiddenAssumptions,
            componentLines: components,
            hiddenComponentCount: hiddenComponents,
            editHintLine: FormaProductCopy.Coach.pendingEditBeforeLoggingHint,
            correctionHintLine: correctionHint,
            sourceLine: sourceLine,
            sanityWarning: draft.sanityWarning,
            accessibilityLabel: accessibilityParts.joined(separator: ". ")
        )
    }

    static func compactDetailLine(for draft: AIFoodConfirmationDraft) -> String? {
        let presentation = presentation(for: draft)
        if let range = presentation.likelyRangeLine {
            return "\(presentation.estimatedCaloriesLine) · \(range)"
        }
        return presentation.estimatedCaloriesLine
    }

    // MARK: - Private

    private static func estimatedCaloriesLine(for calories: Int) -> String {
        guard calories > 0 else {
            return FormaProductCopy.Coach.pendingEstimatedCaloriesUnknown
        }
        return FormaProductCopy.Coach.pendingEstimatedCalories(about: calories)
    }

    private static func likelyRangeLine(for meal: FoodLogDraft) -> String? {
        if let lower = meal.calorieRangeLower,
           let upper = meal.calorieRangeUpper,
           lower <= upper {
            return FormaProductCopy.Coach.pendingLikelyRange(lower: lower, upper: upper)
        }
        if let range = meal.calorieRange, range.hasBounds,
           let lower = range.lowerBound,
           let upper = range.upperBound {
            return FormaProductCopy.Coach.pendingLikelyRange(lower: lower, upper: upper)
        }
        return nil
    }

    private static func confidenceLine(for confidence: AIConfidence) -> String {
        FormaProductCopy.Coach.pendingConfidence(
            label: AIFoodConfirmationFormatter.shortConfidenceLabel(confidence)
        )
    }

    private static func mainUncertaintyLine(for meal: FoodLogDraft) -> String? {
        if let primary = meal.primaryUncertainty?.trimmingCharacters(in: .whitespacesAndNewlines),
           !primary.isEmpty {
            return FormaProductCopy.Coach.pendingMainUncertainty(primary)
        }
        if let reason = meal.uncertaintyReasons.first?.trimmingCharacters(in: .whitespacesAndNewlines),
           !reason.isEmpty {
            return FormaProductCopy.Coach.pendingMainUncertainty(reason)
        }
        return nil
    }

    private static func lowConfidenceWarning(confidence: AIConfidence) -> String? {
        guard confidence == .low else { return nil }
        return FormaProductCopy.Coach.pendingLowConfidenceWarning
    }

    private static func allAssumptions(for meal: FoodLogDraft) -> [String] {
        let structured = meal.assumptions
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if !structured.isEmpty {
            return uniquePreservingOrder(structured)
        }
        return AIFoodConfirmationFormatter.assumptionLines(for: meal)
            .map { line in
                line.replacingOccurrences(of: #"^[^:]+:\s*"#, with: "", options: .regularExpression)
            }
            .filter { !$0.isEmpty }
    }

    private static func visibleAssumptions(for meal: FoodLogDraft) -> [String] {
        Array(allAssumptions(for: meal).prefix(CoachPendingFoodEstimatePresentation.maxVisibleAssumptions))
    }

    private static func visibleComponentLines(for meal: FoodLogDraft) -> [String] {
        guard meal.isMultiComponent || meal.components.count > 1 else {
            guard let component = meal.components.first, component.calories > 0 else { return [] }
            let name = FoodComponentDisplayFormatter.displayName(component.name)
            return [FormaProductCopy.Coach.pendingComponentCalories(name: name, calories: component.calories)]
        }

        return meal.components
            .prefix(CoachPendingFoodEstimatePresentation.maxVisibleComponents)
            .compactMap { component in
                guard component.calories > 0 else { return nil }
                let name = FoodComponentDisplayFormatter.displayName(component.name)
                return FormaProductCopy.Coach.pendingComponentCalories(name: name, calories: component.calories)
            }
    }

    private static func correctionHintLine(for meal: FoodLogDraft) -> String? {
        if let clarification = meal.suggestedClarifications.first?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !clarification.isEmpty {
            return FormaProductCopy.Coach.pendingTellCoachHint(clarification)
        }
        if let uncertainty = meal.primaryUncertainty?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !uncertainty.isEmpty {
            return FormaProductCopy.Coach.pendingTellCoachHint(
                "\(uncertainty.lowercased()) was different"
            )
        }
        return FormaProductCopy.Coach.pendingTellCoachGenericHint
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
