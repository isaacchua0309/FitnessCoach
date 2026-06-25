//
//  CoachResponseBuilder.swift
//  Fitness Coach
//
//  FitPilot AI — Builds deterministic, user-facing assistant strings.
//
//  This builder only formats display text from domain models. It does not call
//  services, access SwiftData, call AI, or own calculations beyond simple
//  display formatting (it may use MacroCalculator for remaining values).
//

import Foundation

enum CoachResponseBuilder {

    // MARK: New Day

    static func newDay(weightKg: Double?) -> String {
        if let weightKg {
            return "Started a new day and logged your weight as \(formatWeight(weightKg)) kg."
        }
        return "Started a new day."
    }

    // MARK: Water

    static func water(loggedMl: Int, log: DailyLog?) -> String {
        var response = "Logged \(loggedMl)ml water."
        if let log {
            response += " You are now at \(log.waterConsumedMl) / \(log.targets.waterTargetMl) ml."
        }
        return response
    }

    // MARK: Weight

    static func weight(_ weightKg: Double) -> String {
        "Logged your weight as \(formatWeight(weightKg)) kg."
    }

    // MARK: Food

    static func food(_ entry: FoodEntry, log: DailyLog?) -> String {
        var response = "Logged \(entry.name): \(entry.calories) kcal, "
            + "\(formatMacro(entry.protein))g protein, "
            + "\(formatMacro(entry.carbs))g carbs, "
            + "\(formatMacro(entry.fat))g fat."
        if let log {
            response += " Today: \(log.totals.calories) / \(log.targets.calorieTarget) kcal."
        }
        return response
    }

    // MARK: Undo

    static func undoFood(_ entry: FoodEntry?) -> String {
        guard let entry else {
            return "There was no food entry to undo."
        }
        return "Undid your last food entry: \(entry.name)."
    }

    static func undoWater(_ entry: WaterEntry?) -> String {
        guard let entry else {
            return "There was no water entry to undo."
        }
        return "Undid your last water entry of \(entry.amountMl)ml."
    }

    // MARK: Status

    static func status(_ log: DailyLog) -> String {
        let targets = MacroCalculator.macroTargets(from: log.targets)
        let remaining = MacroCalculator.remaining(targets: targets, totals: log.totals)
        let remainingCalories = max(remaining.calories, 0)

        return """
        Today so far:
        Calories: \(log.totals.calories) / \(targets.calories) kcal
        Protein: \(formatMacro(log.totals.protein)) / \(formatMacro(targets.protein))g
        Carbs: \(formatMacro(log.totals.carbs)) / \(formatMacro(targets.carbs))g
        Fat: \(formatMacro(log.totals.fat)) / \(formatMacro(targets.fat))g
        Water: \(log.waterConsumedMl) / \(log.targets.waterTargetMl)ml

        You still have \(remainingCalories) kcal remaining.
        """
    }

    // MARK: Daily Review

    static func dailyReview(_ review: DailyReview) -> String {
        DailyReviewFormatter.coachMessage(from: review)
    }

    // MARK: Placeholders

    static let dailyReviewPlaceholder =
        "Daily review is coming in a later step. For now, I can show your current status with \"status\"."

    static let stepsPlaceholder =
        "Step logging is recognized, but saving steps will be added in a later step."

    static let undoLastPlaceholder =
        "Undo last action is not fully supported yet. Try \"undo food\" or \"undo water\"."

    static let needsAIResponse =
        "I understand this likely needs AI interpretation. AI parsing will be added in the next step. "
        + "For now, you can log food with explicit calories and macros, for example: "
        + "\"log chicken breast 413 calories 78 protein 0 carbs 4 fat\"."

    static let unsupportedResponse =
        "I do not support that command locally yet."

    static let ambiguousResponse =
        "I'm not sure which action you wanted. Could you rephrase it?"

    static let aiNotUnderstood =
        "I could not confidently understand that yet. "
        + "Please try rephrasing or log it with explicit calories and macros."

    static let aiNeedsConfirmation =
        "This is an estimate and needs confirmation before logging."

    static let aiFoodPendingConfirmation =
        "I estimated this food, but I need your confirmation before logging it."

    static let aiFoodRejected =
        "No problem — I did not log that food."

    static let aiFoodSaveFailed =
        "I could not save that food entry. Please check the values and try again."

    static let aiMultiActionDeferred =
        "This looks like multiple actions. I'll wait for confirmation before logging food."

    static func aiFoodPendingMessage(assistantMessage: String?) -> String {
        guard let assistantMessage, !assistantMessage.isEmpty else {
            return aiFoodPendingConfirmation
        }
        return "\(assistantMessage)\n\n\(aiFoodPendingConfirmation)"
    }

    // MARK: Formatting Helpers

    private static func formatWeight(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private static func formatMacro(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }
}
