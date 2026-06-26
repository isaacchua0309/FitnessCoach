//
//  LocalNutritionEstimator.swift
//  Fitness Coach
//
//  FitPilot AI — deterministic estimates for common explicit foods.
//

import Foundation

struct LocalFoodEstimate: Equatable, Sendable {
    var draft: FoodDraft
    var confidence: ConfidenceLevel
    var requiresConfirmation: Bool
    var explanation: String

    var foodDraft: FoodDraft { draft }
}

struct LocalNutritionEstimator {

    private enum NutritionBasis: Equatable, Sendable {
        case per100g(calories: Double, protein: Double, carbs: Double, fat: Double)
        case per100ml(calories: Double, protein: Double, carbs: Double, fat: Double)
        case perPiece(calories: Double, protein: Double, carbs: Double, fat: Double)
        case perCup(calories: Double, protein: Double, carbs: Double, fat: Double)
        case perScoop(calories: Double, protein: Double, carbs: Double, fat: Double)
    }

    private struct FoodItem: Equatable, Sendable {
        var name: String
        var aliases: [String]
        var basis: NutritionBasis
        var defaultUnit: String
    }

    private struct Quantity: Equatable, Sendable {
        var amount: Double
        var unit: String
        var rawUnit: String
    }

    private let items: [FoodItem]

    init() {
        self.items = Self.defaultItems
    }

    private static let blockedCompoundPatterns = [
        "chicken rice", "economy rice", "mixed rice", "nasi lemak", "kebab",
        "shawarma", "burrito", "pad thai", "fried rice", "some chicken",
        "a bit of", "bowl of", "plate of", "restaurant", "mcdonald", "shake shack"
    ]

    func isBlockedCompoundFood(_ text: String) -> Bool {
        let lowered = text.lowercased()
        if Self.blockedCompoundPatterns.contains(where: { lowered.contains($0) }) {
            return true
        }
        if lowered.contains("bowl") && !lowered.contains("watermelon") {
            return true
        }
        if lowered.contains("some ") || lowered.contains("a bit ") {
            return true
        }
        return false
    }

    func userAskedToLog(_ input: NormalizedCoachInput) -> Bool {
        let text = input.routingText
        let verbs = ["log", "add", "track", "ate", "had", "eat"]
        return verbs.contains(where: { text.hasPrefix($0) || text.contains(" \($0)") })
    }

    func estimate(_ input: NormalizedCoachInput) -> LocalFoodEstimate? {
        let foodText = stripFoodVerb(from: input.normalizedText)
        guard !isBlockedCompoundFood(foodText) else { return nil }
        guard let quantity = extractQuantity(from: foodText) else { return nil }
        guard let item = bestItemMatch(in: foodText) else { return nil }
        guard let nutrition = nutrition(for: item, quantity: quantity) else { return nil }

        let confidence = confidence(for: item, quantity: quantity, foodText: foodText)
        let draft = FoodDraft(
            mealType: inferredMealType(in: input.normalizedText),
            name: item.name,
            quantity: quantity.amount,
            unit: displayUnit(quantity.unit),
            calories: Int(nutrition.calories.rounded()),
            protein: nutrition.protein,
            carbs: nutrition.carbs,
            fat: nutrition.fat,
            fiber: nil,
            sodium: nil,
            source: .manual,
            confidence: confidence,
            imageUrl: nil,
            notes: "Local estimate: \(formatQuantity(quantity.amount)) \(displayUnit(quantity.unit))."
        )

        return LocalFoodEstimate(
            draft: draft,
            confidence: confidence,
            requiresConfirmation: confidence != .high,
            explanation: "Estimated from Forma's local common-food table."
        )
    }

    private func stripFoodVerb(from text: String) -> String {
        let prefixes = [
            "log food ", "add food ", "track food ", "log ", "add ", "track ",
            "i ate ", "i had ", "ate ", "had ", "eat "
        ]
        for prefix in prefixes where text.hasPrefix(prefix) {
            return String(text.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
        }
        return text
    }

    private func extractQuantity(from text: String) -> Quantity? {
        let patterns = [
            "([0-9]+(?:\\.[0-9]+)?)\\s*(g|gram|grams|kg|ml|milliliter|millilitre|milliliters|millilitres|l|liter|litre|liters|litres|cup|cups|scoop|scoops|piece|pieces|pc|pcs|egg|eggs|bowl|bowls)\\b",
            "\\b(one|two|three|four|five|six)\\s*(cup|cups|scoop|scoops|piece|pieces|egg|eggs|bowl|bowls)\\b"
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            guard
                let match = regex.firstMatch(in: text, range: range),
                match.numberOfRanges >= 3,
                let amountRange = Range(match.range(at: 1), in: text),
                let unitRange = Range(match.range(at: 2), in: text)
            else { continue }

            let amountText = String(text[amountRange])
            let rawUnit = String(text[unitRange])
            let amount = Double(amountText) ?? spelledOutNumber(amountText)
            guard let amount, amount > 0 else { return nil }

            return Quantity(
                amount: normalizedAmount(amount, rawUnit: rawUnit),
                unit: normalizedUnit(rawUnit),
                rawUnit: rawUnit
            )
        }

        return nil
    }

    private func bestItemMatch(in text: String) -> FoodItem? {
        items
            .filter { item in item.aliases.contains(where: { containsPhrase($0, in: text) }) }
            .sorted { lhs, rhs in
                let lhsLength = lhs.aliases.map(\.count).max() ?? 0
                let rhsLength = rhs.aliases.map(\.count).max() ?? 0
                return lhsLength > rhsLength
            }
            .first
    }

    private func containsPhrase(_ phrase: String, in text: String) -> Bool {
        let escaped = NSRegularExpression.escapedPattern(for: phrase)
        let pattern = "\\b\(escaped)\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.firstMatch(in: text, range: range) != nil
    }

    private func nutrition(
        for item: FoodItem,
        quantity: Quantity
    ) -> (calories: Double, protein: Double, carbs: Double, fat: Double)? {
        let multiplier: Double
        let base: (calories: Double, protein: Double, carbs: Double, fat: Double)

        switch (item.basis, quantity.unit) {
        case (.per100g(let calories, let protein, let carbs, let fat), "g"):
            multiplier = quantity.amount / 100
            base = (calories, protein, carbs, fat)
        case (.per100g(let calories, let protein, let carbs, let fat), "kg"):
            multiplier = quantity.amount * 10
            base = (calories, protein, carbs, fat)
        case (.per100ml(let calories, let protein, let carbs, let fat), "ml"):
            multiplier = quantity.amount / 100
            base = (calories, protein, carbs, fat)
        case (.per100ml(let calories, let protein, let carbs, let fat), "l"):
            multiplier = quantity.amount * 10
            base = (calories, protein, carbs, fat)
        case (.perPiece(let calories, let protein, let carbs, let fat), "piece"),
             (.perPiece(let calories, let protein, let carbs, let fat), "egg"):
            multiplier = quantity.amount
            base = (calories, protein, carbs, fat)
        case (.perCup(let calories, let protein, let carbs, let fat), "cup"):
            multiplier = quantity.amount
            base = (calories, protein, carbs, fat)
        case (.perScoop(let calories, let protein, let carbs, let fat), "scoop"):
            multiplier = quantity.amount
            base = (calories, protein, carbs, fat)
        case (.perCup(let calories, let protein, let carbs, let fat), "bowl"):
            multiplier = quantity.amount * 1.5
            base = (calories, protein, carbs, fat)
        default:
            return nil
        }

        return (
            calories: base.calories * multiplier,
            protein: base.protein * multiplier,
            carbs: base.carbs * multiplier,
            fat: base.fat * multiplier
        )
    }

    private func confidence(for item: FoodItem, quantity: Quantity, foodText: String) -> ConfidenceLevel {
        let hasSpecificAlias = item.aliases.contains { alias in
            alias.contains(" ") && containsPhrase(alias, in: foodText)
        }

        if quantity.unit == "bowl" {
            return .low
        }
        if hasSpecificAlias {
            return .high
        }
        return .medium
    }

    private func inferredMealType(in text: String) -> MealType? {
        for mealType in MealType.allCases where mealType != .unknown {
            if CommandParserUtilities.containsWord(mealType.rawValue, in: text) {
                return mealType
            }
        }
        return nil
    }

    private func normalizedUnit(_ rawUnit: String) -> String {
        switch rawUnit {
        case "gram", "grams", "kg": return "g"
        case "milliliter", "millilitre", "milliliters", "millilitres": return "ml"
        case "liter", "litre", "liters", "litres": return "l"
        case "cups": return "cup"
        case "scoops": return "scoop"
        case "piece", "pieces", "pc", "pcs": return "piece"
        case "eggs": return "egg"
        case "bowls": return "bowl"
        default: return rawUnit
        }
    }

    private func normalizedAmount(_ amount: Double, rawUnit: String) -> Double {
        rawUnit == "kg" ? amount * 1_000 : amount
    }

    private func displayUnit(_ unit: String) -> String {
        unit == "kg" ? "g" : unit
    }

    private func spelledOutNumber(_ text: String) -> Double? {
        switch text {
        case "one": return 1
        case "two": return 2
        case "three": return 3
        case "four": return 4
        case "five": return 5
        case "six": return 6
        default: return nil
        }
    }

    private func formatQuantity(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }

    private static let defaultItems: [FoodItem] = [
        FoodItem(name: "Chicken breast", aliases: ["chicken breast"], basis: .per100g(calories: 165, protein: 31, carbs: 0, fat: 3.6), defaultUnit: "g"),
        FoodItem(name: "Chicken thigh", aliases: ["chicken thigh"], basis: .per100g(calories: 209, protein: 26, carbs: 0, fat: 10.9), defaultUnit: "g"),
        FoodItem(name: "ON whey protein", aliases: ["on whey", "whey protein", "whey"], basis: .perScoop(calories: 120, protein: 24, carbs: 3, fat: 1.5), defaultUnit: "scoop"),
        FoodItem(name: "Milk", aliases: ["milk"], basis: .per100ml(calories: 62, protein: 3.3, carbs: 4.8, fat: 3.4), defaultUnit: "ml"),
        FoodItem(name: "Cooked rice", aliases: ["cooked rice", "white rice", "rice"], basis: .perCup(calories: 205, protein: 4.3, carbs: 45, fat: 0.4), defaultUnit: "cup"),
        FoodItem(name: "Egg", aliases: ["egg", "eggs"], basis: .perPiece(calories: 72, protein: 6.3, carbs: 0.4, fat: 4.8), defaultUnit: "piece"),
        FoodItem(name: "Watermelon", aliases: ["watermelon"], basis: .per100g(calories: 30, protein: 0.6, carbs: 7.6, fat: 0.2), defaultUnit: "g"),
        FoodItem(name: "Salmon", aliases: ["salmon"], basis: .per100g(calories: 208, protein: 20, carbs: 0, fat: 13), defaultUnit: "g"),
        FoodItem(name: "Tuna", aliases: ["tuna"], basis: .per100g(calories: 132, protein: 28, carbs: 0, fat: 1.3), defaultUnit: "g"),
        FoodItem(name: "Potato", aliases: ["potato", "potatoes"], basis: .per100g(calories: 87, protein: 1.9, carbs: 20, fat: 0.1), defaultUnit: "g"),
        FoodItem(name: "Cooked pasta", aliases: ["cooked pasta", "pasta"], basis: .perCup(calories: 220, protein: 8, carbs: 43, fat: 1.3), defaultUnit: "cup"),
        FoodItem(name: "Wrap", aliases: ["wrap", "wraps", "tortilla"], basis: .perPiece(calories: 130, protein: 4, carbs: 22, fat: 3.5), defaultUnit: "piece"),
        FoodItem(name: "Apple", aliases: ["apple", "apples"], basis: .perPiece(calories: 95, protein: 0.5, carbs: 25, fat: 0.3), defaultUnit: "piece"),
        FoodItem(name: "Banana", aliases: ["banana", "bananas"], basis: .perPiece(calories: 105, protein: 1.3, carbs: 27, fat: 0.4), defaultUnit: "piece"),
        FoodItem(name: "Orange", aliases: ["orange", "oranges"], basis: .perPiece(calories: 62, protein: 1.2, carbs: 15, fat: 0.2), defaultUnit: "piece")
    ]
}

extension LocalNutritionEstimator {
    static let standard = LocalNutritionEstimator()
}
