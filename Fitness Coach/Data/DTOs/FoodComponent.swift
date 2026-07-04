//
//  FoodComponent.swift
//  Fitness Coach
//
//  FitPilot AI — A single ingredient or food item within a meal log draft.
//

import Foundation

struct FoodComponent: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var quantity: Double?
    var unit: String?
    var preparationState: String?
    var calories: Int
    var protein: Double
    var carbs: Double
    var fat: Double
    var confidence: ConfidenceLevel
    var sourceText: String?
    var estimateTrustMetadata: ComponentEstimateTrustMetadata?

    init(
        id: UUID = UUID(),
        name: String,
        quantity: Double? = nil,
        unit: String? = nil,
        preparationState: String? = nil,
        calories: Int,
        protein: Double,
        carbs: Double,
        fat: Double,
        confidence: ConfidenceLevel = .medium,
        sourceText: String? = nil,
        estimateTrustMetadata: ComponentEstimateTrustMetadata? = nil
    ) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.preparationState = preparationState
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.confidence = confidence
        self.sourceText = sourceText
        self.estimateTrustMetadata = estimateTrustMetadata
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        quantity = try container.decodeIfPresent(Double.self, forKey: .quantity)
        unit = try container.decodeIfPresent(String.self, forKey: .unit)
        preparationState = try container.decodeIfPresent(String.self, forKey: .preparationState)
        calories = try container.decode(Int.self, forKey: .calories)
        protein = try container.decode(Double.self, forKey: .protein)
        carbs = try container.decode(Double.self, forKey: .carbs)
        fat = try container.decode(Double.self, forKey: .fat)
        confidence = try container.decodeIfPresent(ConfidenceLevel.self, forKey: .confidence) ?? .medium
        sourceText = try container.decodeIfPresent(String.self, forKey: .sourceText)
        estimateTrustMetadata = try container.decodeIfPresent(ComponentEstimateTrustMetadata.self, forKey: .estimateTrustMetadata)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(quantity, forKey: .quantity)
        try container.encodeIfPresent(unit, forKey: .unit)
        try container.encodeIfPresent(preparationState, forKey: .preparationState)
        try container.encode(calories, forKey: .calories)
        try container.encode(protein, forKey: .protein)
        try container.encode(carbs, forKey: .carbs)
        try container.encode(fat, forKey: .fat)
        try container.encode(confidence, forKey: .confidence)
        try container.encodeIfPresent(sourceText, forKey: .sourceText)
        if let estimateTrustMetadata {
            try container.encode(estimateTrustMetadata, forKey: .estimateTrustMetadata)
        }
    }

    var hasUsableNutritionEstimate: Bool {
        calories > 0 || protein > 0 || carbs > 0 || fat > 0
    }

    var hasCompleteNutritionEstimate: Bool {
        guard hasUsableNutritionEstimate, calories > 0 else { return false }
        return protein > 0 || carbs > 0 || fat > 0
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case quantity
        case unit
        case preparationState
        case calories
        case protein
        case carbs
        case fat
        case confidence
        case sourceText
        case estimateTrustMetadata
    }
}
