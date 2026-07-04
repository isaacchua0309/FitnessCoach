//
//  FoodDraft.swift
//  Fitness Coach
//
//  FitPilot AI — App-facing input for creating a food entry.
//

import Foundation

struct FoodDraft: Codable, Equatable, Sendable {
    var mealType: MealType?
    var name: String
    var quantity: Double?
    var unit: String?
    var calories: Int
    var protein: Double
    var carbs: Double
    var fat: Double
    var fiber: Double?
    var sodium: Double?
    var source: FoodEntrySource
    var confidence: ConfidenceLevel
    var imageUrl: String?
    var notes: String?

    init(
        mealType: MealType? = nil,
        name: String,
        quantity: Double? = nil,
        unit: String? = nil,
        calories: Int,
        protein: Double,
        carbs: Double,
        fat: Double,
        fiber: Double? = nil,
        sodium: Double? = nil,
        source: FoodEntrySource,
        confidence: ConfidenceLevel,
        imageUrl: String? = nil,
        notes: String? = nil
    ) {
        self.mealType = mealType
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.fiber = fiber
        self.sodium = sodium
        self.source = source
        self.confidence = confidence
        self.imageUrl = imageUrl
        self.notes = notes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mealType = MealType.fromOptionalRawValue(try container.decodeIfPresent(String.self, forKey: .mealType))
        name = try container.decode(String.self, forKey: .name)
        quantity = try container.decodeIfPresent(Double.self, forKey: .quantity)
        unit = try container.decodeIfPresent(String.self, forKey: .unit)
        calories = try container.decode(Int.self, forKey: .calories)
        protein = try container.decode(Double.self, forKey: .protein)
        carbs = try container.decode(Double.self, forKey: .carbs)
        fat = try container.decode(Double.self, forKey: .fat)
        fiber = try container.decodeIfPresent(Double.self, forKey: .fiber)
        sodium = try container.decodeIfPresent(Double.self, forKey: .sodium)
        source = try container.decode(FoodEntrySource.self, forKey: .source)
        confidence = try container.decode(ConfidenceLevel.self, forKey: .confidence)
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
    }

    private enum CodingKeys: String, CodingKey {
        case mealType, name, quantity, unit, calories, protein, carbs, fat
        case fiber, sodium, source, confidence, imageUrl, notes
    }

    /// True when the draft includes at least one non-zero nutrition value worth showing.
    var hasUsableNutritionEstimate: Bool {
        calories > 0 || protein > 0 || carbs > 0 || fat > 0
    }

    /// True when calories and macros form a loggable profile (not calorie-only or macro-only partial input).
    var hasCompleteNutritionEstimate: Bool {
        guard hasUsableNutritionEstimate, calories > 0 else { return false }
        return protein > 0 || carbs > 0 || fat > 0
    }
}
