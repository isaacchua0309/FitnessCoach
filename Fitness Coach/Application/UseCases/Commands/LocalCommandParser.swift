//
//  LocalCommandParser.swift
//  Fitness Coach
//
//  FitPilot AI — Deterministic local command parser.
//
//  This parser ONLY parses. It does not execute actions, call services, touch
//  SwiftData, mutate app state, or invoke AI. It converts simple user text into
//  a structured CommandParseResult.
//

import Foundation

struct LocalCommandParser {

    nonisolated init() {}

    /// Maximum millilitres allowed for a single water entry.
    static let maxSingleWaterMl = 5000

    func parse(_ text: String) -> CommandParseResult {
        let original = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !original.isEmpty else {
            return .unsupported(originalText: text, reason: "Empty command.")
        }

        let normalized = CommandParserUtilities.normalized(original)

        // Deterministic matching order. Earlier, more specific intents are
        // checked first to avoid keyword collisions (for example, "undo weight"
        // must resolve as undo, not weight).
        if let result = parseUndo(normalized: normalized, original: original) {
            return result
        }
        if let result = parseNewDay(normalized: normalized, original: original) {
            return result
        }
        if let result = parseStatus(normalized: normalized, original: original) {
            return result
        }
        if let result = parseDailyReview(normalized: normalized, original: original) {
            return result
        }
        if let result = parseWeight(normalized: normalized, original: original) {
            return result
        }
        if let result = parseWater(normalized: normalized, original: original) {
            return result
        }
        if let result = parseSteps(normalized: normalized, original: original) {
            return result
        }
        if let result = parseFood(normalized: normalized, original: original) {
            return result
        }

        return .unsupported(
            originalText: original,
            reason: "Command not recognized by the local parser."
        )
    }

    // MARK: New Day

    private func parseNewDay(normalized: String, original: String) -> CommandParseResult? {
        let isNewDay = normalized.contains("new day")
            || normalized.contains("reset day")
            || normalized.contains("reset today")
        guard isNewDay else { return nil }

        let weight = CommandParserUtilities.firstDouble(in: normalized)
        if let weight, weight > 0 {
            return .success(
                ParsedCommand(
                    intent: .logWeight(WeightDraft(weightKg: weight)),
                    originalText: original
                )
            )
        }

        return .invalid(
            originalText: original,
            reason: "Your day starts automatically at midnight. Say \"status\" to see today."
        )
    }

    // MARK: Weight

    private func parseWeight(normalized: String, original: String) -> CommandParseResult? {
        guard normalized.contains("weigh")
            || normalized.hasPrefix("weight ")
            || normalized.hasPrefix("log weight ")
        else { return nil }

        let numbers = CommandParserUtilities.allDoubles(in: normalized)
        guard let weightKg = numbers.first else {
            return .invalid(
                originalText: original,
                reason: "Could not find a weight value."
            )
        }

        if numbers.count > 1 {
            return .ambiguous(
                originalText: original,
                reason: CommandParserError.ambiguousNumbers.reason
            )
        }

        guard weightKg > 0 else {
            return .invalid(
                originalText: original,
                reason: CommandParserError.nonPositiveWeight.reason
            )
        }

        let draft = WeightDraft(weightKg: weightKg, note: nil)
        return .success(ParsedCommand(intent: .logWeight(draft), originalText: original))
    }

    // MARK: Water

    private func parseWater(normalized: String, original: String) -> CommandParseResult? {
        let explicitMl = CommandParserUtilities.extractWaterAmountMl(from: normalized)
        let mentionsWater = CommandParserUtilities.containsWord("water", in: normalized)
        guard explicitMl != nil || mentionsWater else { return nil }

        // Prefer an explicit unit; otherwise assume a bare number is millilitres.
        let amountMl = explicitMl ?? CommandParserUtilities.firstInt(in: normalized)
        guard let amountMl else {
            return .invalid(
                originalText: original,
                reason: "Could not find a water amount."
            )
        }

        guard amountMl > 0 else {
            return .invalid(
                originalText: original,
                reason: CommandParserError.nonPositiveWater.reason
            )
        }

        guard amountMl <= Self.maxSingleWaterMl else {
            return .invalid(
                originalText: original,
                reason: CommandParserError.waterTooLarge(maxMl: Self.maxSingleWaterMl).reason
            )
        }

        let draft = WaterDraft(amountMl: amountMl)
        return .success(ParsedCommand(intent: .logWater(draft), originalText: original))
    }

    // MARK: Steps

    private func parseSteps(normalized: String, original: String) -> CommandParseResult? {
        guard CommandParserUtilities.containsWord("steps", in: normalized)
            || CommandParserUtilities.containsWord("step", in: normalized)
        else { return nil }

        guard let steps = CommandParserUtilities.firstInt(in: normalized) else {
            return .invalid(
                originalText: original,
                reason: "Could not find a step count."
            )
        }

        guard steps > 0 else {
            return .invalid(
                originalText: original,
                reason: CommandParserError.nonPositiveSteps.reason
            )
        }

        return .success(ParsedCommand(intent: .logSteps(steps), originalText: original))
    }

    // MARK: Status

    private func parseStatus(normalized: String, original: String) -> CommandParseResult? {
        let phrases = [
            "status",
            "how am i doing",
            "how many calories left",
            "calories left",
            "remaining calories",
            "calories remaining"
        ]
        guard phrases.contains(where: { normalized.contains($0) }) else { return nil }

        return .success(ParsedCommand(intent: .status, originalText: original))
    }

    // MARK: Daily Review

    private func parseDailyReview(normalized: String, original: String) -> CommandParseResult? {
        let phrases = [
            "daily review",
            "review today",
            "today review",
            "summarize today",
            "day summary"
        ]
        guard phrases.contains(where: { normalized.contains($0) }) else { return nil }

        return .success(ParsedCommand(intent: .dailyReview, originalText: original))
    }

    // MARK: Undo

    private func parseUndo(normalized: String, original: String) -> CommandParseResult? {
        guard CommandParserUtilities.containsWord("undo", in: normalized) else { return nil }

        let target: UndoTarget
        if CommandParserUtilities.containsWord("food", in: normalized)
            || CommandParserUtilities.containsWord("meal", in: normalized) {
            target = .food
        } else if CommandParserUtilities.containsWord("water", in: normalized) {
            target = .water
        } else if CommandParserUtilities.containsWord("workout", in: normalized) {
            target = .workout
        } else if normalized.contains("weigh") {
            target = .weight
        } else {
            target = .last
        }

        return .success(ParsedCommand(intent: .undo(target: target), originalText: original))
    }

    // MARK: Food

    private func parseFood(normalized: String, original: String) -> CommandParseResult? {
        guard let verb = foodVerbPrefix(in: normalized) else { return nil }

        let calories = CommandParserUtilities.numberPreceding(keyword: "calories", in: normalized)
            ?? CommandParserUtilities.numberPreceding(keyword: "kcal", in: normalized)
            ?? CommandParserUtilities.numberPreceding(keyword: "cal", in: normalized)

        let protein = macroValue(keywords: ["protein", "p"], in: normalized)
        let carbs = macroValue(keywords: ["carbs", "carb", "c"], in: normalized)
        let fat = macroValue(keywords: ["fat", "f"], in: normalized)

        // Local parsing requires explicit calories AND at least one explicit macro.
        // Anything vaguer is deferred to AI rather than guessed.
        guard let calories, protein != nil || carbs != nil || fat != nil else {
            return .needsAI(
                originalText: original,
                reason: CommandParserError.vagueFood.reason
            )
        }

        guard calories >= 0 else {
            return .invalid(
                originalText: original,
                reason: CommandParserError.negativeCalories.reason
            )
        }

        let proteinValue = protein ?? 0
        let carbsValue = carbs ?? 0
        let fatValue = fat ?? 0

        guard proteinValue >= 0, carbsValue >= 0, fatValue >= 0 else {
            return .invalid(
                originalText: original,
                reason: CommandParserError.negativeMacro.reason
            )
        }

        let name = foodName(normalized: normalized, verb: verb)
        guard !name.isEmpty else {
            return .invalid(
                originalText: original,
                reason: CommandParserError.emptyFoodName.reason
            )
        }

        let draft = FoodDraft(
            mealType: nil,
            name: name,
            quantity: nil,
            unit: nil,
            calories: Int(calories.rounded()),
            protein: proteinValue,
            carbs: carbsValue,
            fat: fatValue,
            fiber: nil,
            sodium: nil,
            source: .manual,
            confidence: .high,
            imageUrl: nil,
            notes: nil
        )
        return .success(ParsedCommand(intent: .logFood(draft), originalText: original))
    }

    // MARK: Food Helpers

    private func macroValue(keywords: [String], in text: String) -> Double? {
        for keyword in keywords {
            if let value = CommandParserUtilities.numberPreceding(keyword: keyword, in: text) {
                return value
            }
        }
        return nil
    }

    /// Leading verb that signals a food-logging command. Order matters so that
    /// the longer "log food"/"add food" phrases are matched before "log"/"add".
    private func foodVerbPrefix(in normalized: String) -> String? {
        let verbs = ["log food ", "add food ", "log ", "add ", "track ", "ate ", "eat ", "had "]
        return verbs.first { normalized.hasPrefix($0) }
    }

    /// Extracts the food name: the text after the leading verb and before the
    /// first numeric value.
    private func foodName(normalized: String, verb: String) -> String {
        var remainder = normalized
        if remainder.hasPrefix(verb) {
            remainder.removeFirst(verb.count)
        }

        if let digitIndex = remainder.firstIndex(where: { $0.isNumber }) {
            remainder = String(remainder[remainder.startIndex..<digitIndex])
        }

        return remainder.trimmingCharacters(in: .whitespaces)
    }
}

extension LocalCommandParser {
    nonisolated static let standard = LocalCommandParser()
}
