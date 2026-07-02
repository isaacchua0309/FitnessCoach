//
//  CoachFoodEstimateDebugLogger.swift
//  Fitness Coach
//
//  FitPilot AI — Local DEBUG-only tracing for Coach food estimate pipelines.
//

import Foundation
import OSLog

/// Snapshot of a single Coach food estimate for local diagnosis.
/// Formatting helpers are testable; emission is DEBUG-only.
struct CoachFoodEstimateDebugSnapshot: Equatable, Sendable {
    enum Source: String, Sendable {
        case aiText
        case aiPhoto
        case localEstimator
        case parsedCommand
    }

    var source: Source
    var originalText: String
    var llmMealDraft: FoodLogDraft?
    var fallbackMealDraft: FoodLogDraft?
    var fallbackLabel: String?
    var sanitizedMealDraft: FoodLogDraft
    var sanityResult: NutritionSanityResult
    var displayedMealDraft: FoodLogDraft
    var responseConfidence: AIConfidence
    var sanityWarning: String?
}

enum CoachFoodEstimateDebugLogFormatter {

    static func componentsSummary(_ components: [FoodComponent]) -> String {
        guard !components.isEmpty else { return "none" }
        return components.map(componentLine).joined(separator: " || ")
    }

    static func totalsSummary(for meal: FoodLogDraft) -> String {
        "cal=\(meal.totalCalories) P=\(formatMacro(meal.totalProtein)) " +
        "C=\(formatMacro(meal.totalCarbs)) F=\(formatMacro(meal.totalFat))"
    }

    static func sanitySummary(_ result: NutritionSanityResult) -> String {
        let acceptable = result.isAcceptable ? "acceptable" : "flagged"
        let issues = result.issues.isEmpty ? "none" : result.issues.joined(separator: "; ")
        return "\(acceptable) confidence=\(result.confidence.rawValue) issues=[\(issues)]"
    }

    static func warningsSummary(_ warnings: [String]) -> String {
        warnings.isEmpty ? "none" : warnings.joined(separator: " | ")
    }

    private static func componentLine(_ component: FoodComponent) -> String {
        var parts = [component.name]
        if let quantity = component.quantity {
            let unit = component.unit ?? ""
            parts.append(unit.isEmpty ? formatQuantity(quantity) : "\(formatQuantity(quantity))\(unit)")
        }
        if let preparation = component.preparationState, !preparation.isEmpty {
            parts.append(preparation)
        }
        parts.append(
            "\(component.calories)kcal P\(formatMacro(component.protein)) " +
            "C\(formatMacro(component.carbs)) F\(formatMacro(component.fat))"
        )
        return parts.joined(separator: " | ")
    }

    private static func formatMacro(_ value: Double) -> String {
        FoodEntryFormFormatter.formatMacro(value)
    }

    private static func formatQuantity(_ value: Double) -> String {
        FoodEntryFormFormatter.formatOptionalDouble(value) ?? String(value)
    }
}

enum CoachFoodEstimateDebugLogger {

    static func log(_ snapshot: CoachFoodEstimateDebugSnapshot) {
        #if DEBUG
        guard isEnabled else { return }
        emit(snapshot)
        #endif
    }

    #if DEBUG
    private static let logger = Logger(subsystem: "Forma", category: "CoachFoodEstimate")

    /// Disable with `FORMA_FOOD_ESTIMATE_DEBUG=0`.
    static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["FORMA_FOOD_ESTIMATE_DEBUG"] != "0"
    }

    private static func emit(_ snapshot: CoachFoodEstimateDebugSnapshot) {
        let parsedMeal = snapshot.llmMealDraft ?? snapshot.fallbackMealDraft ?? snapshot.sanitizedMealDraft
        let parsedComponents = CoachFoodEstimateDebugLogFormatter.componentsSummary(parsedMeal.components)
        let llmTotals = snapshot.llmMealDraft.map(CoachFoodEstimateDebugLogFormatter.totalsSummary)
        let fallbackTotals = snapshot.fallbackMealDraft.map(CoachFoodEstimateDebugLogFormatter.totalsSummary)
        let finalTotals = CoachFoodEstimateDebugLogFormatter.totalsSummary(snapshot.displayedMealDraft)
        let sanity = CoachFoodEstimateDebugLogFormatter.sanitySummary(snapshot.sanityResult)
        let warnings = CoachFoodEstimateDebugLogFormatter.warningsSummary(snapshot.displayedMealDraft.warnings)

        logger.debug(
            """
            [CoachFoodEstimate] source=\(snapshot.source.rawValue, privacy: .public) \
            confidence=\(snapshot.responseConfidence.rawValue, privacy: .public) \
            displayedConfidence=\(snapshot.sanityResult.confidence.rawValue, privacy: .public)
            """
        )
        logger.debug("originalText=\(snapshot.originalText, privacy: .public)")
        logger.debug("parsedComponents=\(parsedComponents, privacy: .public)")
        if let llmTotals {
            logger.debug("llmRawTotals=\(llmTotals, privacy: .public)")
        } else {
            logger.debug("llmRawTotals=none")
        }
        if let fallbackTotals {
            let label = snapshot.fallbackLabel ?? "deterministic_fallback"
            logger.debug(
                "deterministicFallbackTotals[\(label, privacy: .public)]=\(fallbackTotals, privacy: .public)"
            )
        } else {
            logger.debug("deterministicFallbackTotals=none")
        }
        logger.debug("sanityValidation=\(sanity, privacy: .public)")
        if let sanityWarning = snapshot.sanityWarning, !sanityWarning.isEmpty {
            logger.debug("sanityWarning=\(sanityWarning, privacy: .public)")
        }
        logger.debug("finalDisplayedDraft=\(snapshot.displayedMealDraft.displayName, privacy: .public) \(finalTotals, privacy: .public)")
        logger.debug(
            "finalComponents=\(CoachFoodEstimateDebugLogFormatter.componentsSummary(snapshot.displayedMealDraft.components), privacy: .public)"
        )
        logger.debug("warnings=\(warnings, privacy: .public)")
    }
    #endif
}
