//
//  FoodLoggingCompoundGoldenFixtures.swift
//  Fitness CoachTests
//
//  Compound/local dish golden fixtures mirroring functions/test/fixtures/foodLoggingGoldenCases.ts cases 6–17.
//

import Foundation
@testable import Fitness_Coach

enum FoodLoggingCompoundGoldenFixtures {

    struct CompoundCase {
        let id: String
        let prompt: String
        let gatewayResponse: AIFoodEstimateResponse
        let collapsedResponse: AIFoodEstimateResponse?
        let minComponents: Int
        let maxConfidence: AIConfidence?
        let requiresAssumptions: Bool
    }

    static let chickenRice = makeCase(
        id: "case6_chicken_rice",
        prompt: "log chicken rice",
        components: [
            component("fragrant rice", qty: 200, unit: "g", state: "cooked", cal: 260, p: 5, c: 56, f: 1, source: "chicken rice rice portion"),
            component("poached chicken", qty: 120, unit: "g", state: "cooked", cal: 198, p: 37, c: 0, f: 4.5, source: "chicken rice chicken portion"),
            component("chili sauce and chicken oil", qty: 1, unit: "tbsp", cal: 70, p: 0, c: 2, f: 7, source: "chicken rice sauce/oil", confidence: .low)
        ],
        confidence: .medium,
        assumptions: [
            "Assumed standard plate with ~200g cooked rice and ~120g chicken.",
            "Included ~1 tbsp chili sauce and chicken oil.",
            "Medium confidence because exact stall portion is unknown.",
            "User can clarify white/dark meat, extra skin, or larger rice portion."
        ],
        minComponents: 3,
        collapsed: collapsedMeal(name: "chicken rice", cal: 430, source: "log chicken rice")
    )

    static let nasiLemak = makeCase(
        id: "case7_nasi_lemak",
        prompt: "log nasi lemak",
        components: [
            component("coconut rice", qty: 200, unit: "g", state: "cooked", cal: 330, p: 6, c: 58, f: 8, source: "nasi lemak coconut rice"),
            component("fried egg", qty: 1, unit: "piece", state: "cooked", cal: 90, p: 6, c: 0, f: 7, source: "nasi lemak egg"),
            component("sambal", qty: 1, unit: "tbsp", cal: 25, p: 0, c: 3, f: 1.5, source: "nasi lemak sambal", confidence: .low),
            component("ikan bilis and peanuts", qty: 15, unit: "g", state: "cooked", cal: 85, p: 4, c: 3, f: 6, source: "nasi lemak ikan bilis/peanuts", confidence: .low)
        ],
        confidence: .medium,
        assumptions: [
            "Assumed standard packet/set with ~200g coconut rice.",
            "Included typical sambal, egg, and ikan bilis/peanuts.",
            "Medium confidence without stated add-ons like wing or otah.",
            "User can clarify protein add-on or larger rice portion."
        ],
        minComponents: 4
    )

    static let ambiguousRiceBowl = makeCase(
        id: "case17_ambiguous_rice_bowl",
        prompt: "rice bowl",
        components: [
            component("cooked rice", qty: 200, unit: "g", state: "cooked", cal: 260, p: 5, c: 56, f: 0.5, source: "rice bowl", confidence: .low),
            component("cooking oil or topping allowance", qty: 1, unit: "tsp", cal: 40, p: 0, c: 0, f: 4.5, source: "possible topping/oil", confidence: .low)
        ],
        confidence: .low,
        assumptions: [
            "Assumed plain medium rice bowl ~200g without stated topping.",
            "Included small oil/topping allowance because bowl type is unclear.",
            "Low confidence because protein/toppings were not specified.",
            "User can clarify topping, protein, or smaller/larger bowl."
        ],
        warnings: ["Serving size is ambiguous."],
        minComponents: 1,
        maxConfidence: .low
    )

    static let allCases: [CompoundCase] = [
        chickenRice,
        nasiLemak,
        ambiguousRiceBowl
    ]

    // MARK: - Helpers

    private static func makeCase(
        id: String,
        prompt: String,
        components: [FoodComponent],
        confidence: AIConfidence,
        assumptions: [String],
        warnings: [String] = [],
        minComponents: Int,
        maxConfidence: AIConfidence? = .medium,
        collapsed: AIFoodEstimateResponse? = nil
    ) -> CompoundCase {
        let meal = FoodLogDraft(
            displayName: components.map(\.name).joined(separator: ", "),
            components: components,
            confidence: confidence,
            source: .aiTextEstimate,
            warnings: assumptions.map { "Assumption: \($0)" } + warnings
        )
        return CompoundCase(
            id: id,
            prompt: prompt,
            gatewayResponse: AIFoodEstimateResponse(
                foodLogDrafts: [meal],
                confidence: confidence,
                requiresConfirmation: true
            ),
            collapsedResponse: collapsed,
            minComponents: minComponents,
            maxConfidence: maxConfidence,
            requiresAssumptions: true
        )
    }

    private static func component(
        _ name: String,
        qty: Double,
        unit: String,
        state: String? = nil,
        cal: Int,
        p: Double,
        c: Double,
        f: Double,
        source: String,
        confidence: AIConfidence = .medium
    ) -> FoodComponent {
        FoodComponent(
            name: name,
            quantity: qty,
            unit: unit,
            preparationState: state,
            calories: cal,
            protein: p,
            carbs: c,
            fat: f,
            confidence: confidence,
            sourceText: source
        )
    }

    private static func collapsedMeal(name: String, cal: Int, source: String) -> AIFoodEstimateResponse {
        AIFoodEstimateResponse(
            foodLogDrafts: [
                FoodLogDraft(
                    displayName: name,
                    components: [
                        FoodComponent(
                            name: name,
                            quantity: 1,
                            unit: "plate",
                            calories: cal,
                            protein: 28,
                            carbs: 52,
                            fat: 10,
                            sourceText: source
                        )
                    ],
                    confidence: .low,
                    source: .aiTextEstimate
                )
            ],
            confidence: .low,
            requiresConfirmation: true
        )
    }
}
