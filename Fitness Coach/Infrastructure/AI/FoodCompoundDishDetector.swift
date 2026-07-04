//
//  FoodCompoundDishDetector.swift
//  Fitness Coach
//
//  FitPilot AI — Detects compound/local dishes requiring component decomposition.
//

import Foundation

struct CompoundDishSpec: Equatable, Sendable {
    let id: String
    let label: String
    let patterns: [String]
    let minComponents: Int
    let decompositionHint: String
}

struct CompoundFoodPromptAnalysis: Equatable, Sendable {
    let matchedDishes: [CompoundDishSpec]
    let minRequiredComponents: Int
    let isAmbiguousServing: Bool
    let requiresAssumptions: Bool
    let hasHugePortionHint: Bool
    let isContextReference: Bool
}

enum FoodCompoundDishDetector {

    private static let compoundDishes: [CompoundDishSpec] = [
        CompoundDishSpec(
            id: "chicken_rice",
            label: "chicken rice",
            patterns: [#"\bchicken rice\b"#, #"\bhainanese chicken\b"#, #"\bhainanese\b"#],
            minComponents: 3,
            decompositionHint: "rice, chicken, skin/oil/sauce if relevant"
        ),
        CompoundDishSpec(
            id: "nasi_lemak",
            label: "nasi lemak",
            patterns: [#"\bnasi lemak\b"#],
            minComponents: 4,
            decompositionHint: "coconut rice, egg, sambal, ikan bilis/peanuts, protein"
        ),
        CompoundDishSpec(
            id: "cai_fan",
            label: "cai fan",
            patterns: [#"\bcai fan\b"#, #"\bcai png\b"#, #"\beconomy rice\b"#, #"\bmixed rice\b"#],
            minComponents: 2,
            decompositionHint: "rice plus each selected dish"
        ),
        CompoundDishSpec(
            id: "mala",
            label: "mala",
            patterns: [#"\bmala\b"#, #"\bmalatang\b"#],
            minComponents: 3,
            decompositionHint: "noodles/rice if stated, meat, vegetables, oil/sauce"
        ),
        CompoundDishSpec(
            id: "ban_mian",
            label: "ban mian",
            patterns: [#"\bban mian\b"#, #"\bbanmian\b"#],
            minComponents: 2,
            decompositionHint: "noodles, broth/toppings, egg or minced meat if stated"
        ),
        CompoundDishSpec(
            id: "yong_tau_foo",
            label: "yong tau foo",
            patterns: [#"\byong tau foo\b"#, #"\bytf\b"#],
            minComponents: 2,
            decompositionHint: "selected items plus soup/sauce/noodles if stated"
        ),
        CompoundDishSpec(
            id: "prata",
            label: "prata",
            patterns: [#"\bprata\b"#, #"\broti prata\b"#],
            minComponents: 1,
            decompositionHint: "prata plus curry or sugar if stated"
        ),
        CompoundDishSpec(
            id: "bubble_tea",
            label: "bubble tea",
            patterns: [#"\bbubble tea\b"#, #"\bboba\b"#, #"\bmilk tea\b"#, #"\bpearl milk tea\b"#],
            minComponents: 2,
            decompositionHint: "drink base, milk/sugar, toppings"
        ),
    ]

    static func analyze(prompt: String) -> CompoundFoodPromptAnalysis {
        let normalized = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let matched = matchCompoundDishes(in: normalized)
        let hasHuge = hasHugePortionHint(in: normalized)
        let ambiguous = isAmbiguousServingPrompt(normalized)
        let contextRef = isContextReferencePrompt(normalized)

        var minRequired = 0
        if !matched.isEmpty {
            minRequired = matched.map { dish in dishMinComponents(for: dish, prompt: normalized) }.max() ?? 0
        }

        let requiresAssumptions = ambiguous
            || contextRef
            || !matched.isEmpty
            || normalized.range(
                of: #"\b(one|a|an|small|medium|large)\s+(bowl|plate|cup|serving|portion)\b"#,
                options: [.regularExpression, .caseInsensitive]
            ) != nil

        return CompoundFoodPromptAnalysis(
            matchedDishes: matched,
            minRequiredComponents: minRequired,
            isAmbiguousServing: ambiguous,
            requiresAssumptions: requiresAssumptions,
            hasHugePortionHint: hasHuge,
            isContextReference: contextRef
        )
    }

    static func isKnownCompoundDish(_ prompt: String) -> Bool {
        !matchCompoundDishes(in: prompt).isEmpty
    }

    static func componentNamesMatchCompound(_ componentNames: [String], dish: CompoundDishSpec) -> Bool {
        let combined = componentNames.joined(separator: " ").lowercased()
        switch dish.id {
        case "chicken_rice":
            return combined.contains("rice") && combined.contains("chicken")
        case "nasi_lemak":
            return combined.contains("rice")
                && (combined.contains("sambal") || combined.contains("egg") || combined.contains("lemak"))
        case "cai_fan":
            return combined.contains("rice")
        case "mala":
            let hasProtein = ["meat", "beef", "pork", "chicken", "seafood"].contains(where: { combined.contains($0) })
            let hasVegOrBase = ["vegetable", "veg", "mushroom", "noodle", "rice"].contains(where: { combined.contains($0) })
            return hasProtein && hasVegOrBase
        case "ban_mian":
            return combined.contains("noodle") || combined.contains("mian")
        case "yong_tau_foo":
            return combined.contains("tofu") || combined.contains("fish") || combined.contains("item")
                || combined.contains("soup")
        case "prata":
            return combined.contains("prata") || combined.contains("roti")
        case "bubble_tea":
            return combined.contains("tea") || combined.contains("boba") || combined.contains("pearl")
                || combined.contains("milk")
        default:
            return true
        }
    }

    static let lowConfidenceReviewMessage =
        "This estimate used assumptions — review portions and components before logging."

    // MARK: - Private

    private static func matchCompoundDishes(in text: String) -> [CompoundDishSpec] {
        if text.range(of: #"\bprotein shake\b"#, options: .regularExpression) != nil {
            return []
        }
        return compoundDishes.filter { dish in
            dish.patterns.contains { pattern in
                text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
            }
        }
    }

    private static func dishMinComponents(for dish: CompoundDishSpec, prompt: String) -> Int {
        switch dish.id {
        case "cai_fan":
            return 1 + countCaiFanDishes(in: prompt)
        case "prata":
            return prataMinComponents(in: prompt)
        default:
            return dish.minComponents
        }
    }

    private static func countCaiFanDishes(in text: String) -> Int {
        guard let range = text.range(of: #"\bwith\s+(.+)$"#, options: [.regularExpression, .caseInsensitive]) else {
            return 1
        }
        let dishPart = String(text[range]).replacingOccurrences(of: "with ", with: "", options: .caseInsensitive)
        let dishes = dishPart
            .components(separatedBy: CharacterSet(charactersIn: ",+"))
            .flatMap { $0.components(separatedBy: " and ") }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count > 2 }
        return max(dishes.count, 1)
    }

    private static func prataMinComponents(in text: String) -> Int {
        if text.range(
            of: #"\b(with curry|curry|sugar|dhall|dhal)\b"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil {
            return 2
        }
        return 1
    }

    private static func hasHugePortionHint(in text: String) -> Bool {
        text.range(
            of: #"\b(huge|extra large|double|2x|two bowls?|large portion|big portion|super size|upsized)\b"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }

    private static func isAmbiguousServingPrompt(_ text: String) -> Bool {
        if text.range(of: #"\brice bowl\b"#, options: [.regularExpression, .caseInsensitive]) != nil {
            return true
        }
        if text.range(of: #"^log rice bowl$"#, options: [.regularExpression, .caseInsensitive]) != nil {
            return true
        }
        return text.range(of: #"^rice bowl$"#, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private static func isContextReferencePrompt(_ text: String) -> Bool {
        text.range(
            of: #"\b(same as|like my|like the)\s+(breakfast|lunch|dinner|usual|yesterday)\b"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }
}
