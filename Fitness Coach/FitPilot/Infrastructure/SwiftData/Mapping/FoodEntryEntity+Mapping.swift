//
//  FoodEntryEntity+Mapping.swift
//  Fitness Coach
//
//  FitPilot AI — SwiftData mapping between entity and domain model.
//

import Foundation

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
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
