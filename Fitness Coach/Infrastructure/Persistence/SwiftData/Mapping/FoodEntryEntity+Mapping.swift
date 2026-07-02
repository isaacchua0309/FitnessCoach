//
//  FoodEntryEntity+Mapping.swift
//  Fitness Coach
//
//  FitPilot AI — SwiftData mapping between entity and domain model.
//

import Foundation

private enum FoodComponentCoding {
    static let encoder = JSONEncoder()
    static let decoder = JSONDecoder()

    static func encode(_ components: [FoodComponent]) -> String? {
        guard let data = try? encoder.encode(components) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func decode(_ json: String?) -> [FoodComponent]? {
        guard let json,
              let data = json.data(using: .utf8),
              let components = try? decoder.decode([FoodComponent].self, from: data),
              !components.isEmpty else {
            return nil
        }
        return components
    }
}

extension FoodEntryEntity {

    convenience init(model: FoodEntry) {
        self.init(
            id: model.id,
            dailyLogId: model.dailyLogId,
            mealTypeRawValue: model.mealType?.rawValue,
            name: model.name,
            quantity: model.quantity,
            unit: model.unit,
            calories: model.calories,
            protein: model.protein,
            carbs: model.carbs,
            fat: model.fat,
            fiber: model.fiber,
            sodium: model.sodium,
            sourceRawValue: model.source.rawValue,
            confidenceRawValue: model.confidence.rawValue,
            imageUrl: model.imageUrl,
            notes: model.notes,
            componentsJSON: model.isMultiComponent
                ? FoodComponentCoding.encode(model.components ?? [])
                : nil,
            createdAt: model.createdAt,
            updatedAt: model.updatedAt
        )
    }

    func toModel() -> FoodEntry {
        FoodEntry(
            id: id,
            dailyLogId: dailyLogId,
            mealType: mealTypeRawValue.flatMap { MealType(rawValue: $0) } ?? .unknown,
            name: name,
            quantity: quantity,
            unit: unit,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            fiber: fiber,
            sodium: sodium,
            source: FoodEntrySource(rawValue: sourceRawValue) ?? .manual,
            confidence: ConfidenceLevel(rawValue: confidenceRawValue) ?? .low,
            imageUrl: imageUrl,
            notes: notes,
            components: FoodComponentCoding.decode(componentsJSON),
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
