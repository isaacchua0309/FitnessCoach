//
//  FoodMealDisplayNameFormatter.swift
//  Fitness Coach
//
//  FitPilot AI — Human-readable meal titles for multi-component food logs.
//

import Foundation

enum FoodMealDisplayNameFormatter {

    static func readableDisplayName(
        proposed: String,
        components: [FoodComponent]
    ) -> String {
        let trimmed = proposed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard components.count > 1 else {
            let fallback = trimmed.isEmpty ? (components.first?.name ?? "") : trimmed
            return FoodEntryFormFormatter.displayFoodName(fallback)
        }
        guard isGenericCompositeName(trimmed) else {
            return trimmed
        }
        return buildName(from: components)
    }

    private static func isGenericCompositeName(_ name: String) -> Bool {
        let lowered = name.lowercased()
        let genericPrefixes = [
            "bowl with ",
            "plate with ",
            "meal with ",
            "salad with ",
            "dish with "
        ]
        if genericPrefixes.contains(where: { lowered.hasPrefix($0) }) {
            return true
        }
        if name.filter({ $0 == "," }).count >= 2 {
            return true
        }
        if lowered.contains(", and ") {
            return true
        }
        if lowered.contains(" mix,") || lowered.hasSuffix(" mix") {
            return true
        }
        return false
    }

    private static func buildName(from components: [FoodComponent]) -> String {
        var protein: String?
        var grain: String?
        var desserts: [String] = []
        var fallbackMain: String?

        for component in components {
            let keywords = component.name.lowercased()
            if isCondiment(keywords) { continue }

            if isDessert(keywords) {
                desserts.append(shortLabel(from: component.name, role: .dessert))
                continue
            }
            if protein == nil, isProtein(keywords) {
                protein = shortLabel(from: component.name, role: .protein)
                continue
            }
            if grain == nil, isGrain(keywords) {
                grain = shortLabel(from: component.name, role: .grain)
                continue
            }
            if fallbackMain == nil {
                fallbackMain = shortLabel(from: component.name, role: .other)
            }
        }

        let bowlName: String
        if let protein, let grain {
            bowlName = "\(titleCase(protein)) \(grain) bowl"
        } else if let protein {
            bowlName = "\(titleCase(protein)) bowl"
        } else if let grain {
            bowlName = "\(titleCase(grain)) bowl"
        } else if let fallbackMain {
            bowlName = "\(titleCase(fallbackMain)) bowl"
        } else {
            bowlName = "Mixed meal"
        }

        guard !desserts.isEmpty else { return bowlName }
        let suffix = desserts.joined(separator: " and ")
        return "\(bowlName) with \(suffix)"
    }

    private enum Role {
        case protein
        case grain
        case dessert
        case other
    }

    private static func shortLabel(from name: String, role: Role) -> String {
        let words = name
            .lowercased()
            .replacingOccurrences(of: "/", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .filter { !prepWords.contains($0) }

        switch role {
        case .protein:
            if let match = words.first(where: { proteinKeywords.contains($0) }) {
                return match
            }
            return words.prefix(2).joined(separator: " ")
        case .grain:
            if words.contains("barley") { return "barley" }
            if words.contains("quinoa") { return "quinoa" }
            if words.contains("pasta") { return "pasta" }
            if words.contains("noodles") { return "noodles" }
            if words.contains("rice") {
                return words.contains("brown") ? "brown rice" : "rice"
            }
            return words.prefix(2).joined(separator: " ")
        case .dessert, .other:
            return words.joined(separator: " ").lowercased()
        }
    }

    private static func titleCase(_ text: String) -> String {
        FoodEntryFormFormatter.displayFoodName(text)
    }

    private static func isProtein(_ keywords: String) -> Bool {
        proteinKeywords.contains(where: { keywords.contains($0) })
    }

    private static func isGrain(_ keywords: String) -> Bool {
        grainKeywords.contains(where: { keywords.contains($0) })
    }

    private static func isDessert(_ keywords: String) -> Bool {
        dessertKeywords.contains(where: { keywords.contains($0) })
    }

    private static func isCondiment(_ keywords: String) -> Bool {
        condimentKeywords.contains(where: { keywords.contains($0) })
    }

    private static let prepWords: Set<String> = [
        "cooked", "raw", "grilled", "baked", "fried", "roasted", "steamed",
        "boiled", "skinless", "boneless", "fresh", "creamy", "homemade"
    ]

    private static let proteinKeywords = [
        "chicken", "beef", "pork", "turkey", "salmon", "tuna", "fish", "shrimp",
        "tofu", "egg", "steak", "lamb", "duck", "sausage", "bacon", "ham"
    ]

    private static let grainKeywords = [
        "rice", "barley", "quinoa", "pasta", "noodle", "couscous", "oat", "bread"
    ]

    private static let dessertKeywords = [
        "tiramisu", "cake", "cookie", "brownie", "ice cream", "dessert", "pie",
        "pudding", "donut", "muffin", "pastry", "cheesecake"
    ]

    private static let condimentKeywords = [
        "dressing", "sauce", "mayo", "mayonnaise", "ketchup", "mustard", "vinaigrette",
        "relish", "salsa", "gravy"
    ]
}
