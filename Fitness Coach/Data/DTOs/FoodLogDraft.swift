//
//  FoodLogDraft.swift
//  Fitness Coach
//
//  FitPilot AI — Multi-component meal draft for Coach food logging.
//

import Foundation

struct FoodLogDraft: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var displayName: String
    var mealType: MealType?
    var components: [FoodComponent]
    var confidence: ConfidenceLevel
    var source: FoodEntrySource
    var notes: String?
    var warnings: [String]
    var assumptions: [String]
    var caloriesRangeLower: Int?
    var caloriesRangeUpper: Int?
    var imageUrl: String?

    init(
        id: UUID = UUID(),
        displayName: String,
        mealType: MealType? = nil,
        components: [FoodComponent],
        confidence: ConfidenceLevel = .medium,
        source: FoodEntrySource = .aiTextEstimate,
        notes: String? = nil,
        warnings: [String] = [],
        assumptions: [String] = [],
        caloriesRangeLower: Int? = nil,
        caloriesRangeUpper: Int? = nil,
        imageUrl: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.mealType = mealType
        self.components = components
        self.confidence = confidence
        self.source = source
        self.notes = notes
        self.warnings = warnings
        self.assumptions = assumptions
        self.caloriesRangeLower = caloriesRangeLower
        self.caloriesRangeUpper = caloriesRangeUpper
        self.imageUrl = imageUrl
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        displayName = try container.decode(String.self, forKey: .displayName)
        mealType = MealType.fromOptionalRawValue(try container.decodeIfPresent(String.self, forKey: .mealType))
        components = try container.decode([FoodComponent].self, forKey: .components)
        confidence = try container.decodeIfPresent(ConfidenceLevel.self, forKey: .confidence) ?? .medium
        source = try container.decodeIfPresent(FoodEntrySource.self, forKey: .source) ?? .aiTextEstimate
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        warnings = try container.decodeIfPresent([String].self, forKey: .warnings) ?? []
        assumptions = try container.decodeIfPresent([String].self, forKey: .assumptions) ?? []
        caloriesRangeLower = try container.decodeIfPresent(Int.self, forKey: .caloriesRangeLower)
        caloriesRangeUpper = try container.decodeIfPresent(Int.self, forKey: .caloriesRangeUpper)
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
    }

    var totalCalories: Int {
        components.reduce(0) { $0 + $1.calories }
    }

    var totalProtein: Double {
        components.reduce(0) { $0 + $1.protein }
    }

    var totalCarbs: Double {
        components.reduce(0) { $0 + $1.carbs }
    }

    var totalFat: Double {
        components.reduce(0) { $0 + $1.fat }
    }

    var isMultiComponent: Bool {
        components.count > 1
    }

    var hasUsableNutritionEstimate: Bool {
        totalCalories > 0 || totalProtein > 0 || totalCarbs > 0 || totalFat > 0
    }

    var hasCompleteNutritionEstimate: Bool {
        guard hasUsableNutritionEstimate, totalCalories > 0 else { return false }
        return totalProtein > 0 || totalCarbs > 0 || totalFat > 0
    }

    var hasCalorieRange: Bool {
        guard let lower = caloriesRangeLower, let upper = caloriesRangeUpper else { return false }
        return lower >= 0 && upper >= lower
    }

    /// Portion for legacy single-item display. Mixed meals intentionally omit a scalar amount.
    var legacyQuantity: Double? {
        guard !isMultiComponent else { return nil }
        return components.first?.quantity
    }

    var legacyUnit: String? {
        guard !isMultiComponent else { return nil }
        return components.first?.unit
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case displayName
        case mealType
        case components
        case confidence
        case source
        case notes
        case warnings
        case assumptions
        case caloriesRangeLower
        case caloriesRangeUpper
        case imageUrl
    }
}
