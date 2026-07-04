//
//  FoodEntryEntity.swift
//  Fitness Coach
//
//  FitPilot AI — SwiftData persistence entity.
//

import Foundation
import SwiftData

@Model
final class FoodEntryEntity {

    // MARK: Identity

    @Attribute(.unique) var id: UUID
    /// Firebase UID that owns this food entry, when known.
    var ownerUID: String?
    var dailyLogId: UUID

    // MARK: Description

    var mealTypeRawValue: String?
    var name: String
    var quantity: Double?
    var unit: String?

    // MARK: Nutrition

    var calories: Int
    var protein: Double
    var carbs: Double
    var fat: Double
    var fiber: Double?
    var sodium: Double?

    // MARK: Provenance

    var sourceRawValue: String
    var confidenceRawValue: String
    var imageUrl: String?
    var notes: String?
    /// JSON-encoded `[FoodComponent]` for multi-component meals.
    var componentsJSON: String?

    // MARK: Metadata

    var createdAt: Date
    var updatedAt: Date

    // MARK: Account persistence sync metadata (Phase 3)

    var cloudId: String?
    var cloudUpdatedAt: Date?
    var lastSyncedAt: Date?
    var syncStatusRawValue: String = AccountDataSyncStatus.localOnly.rawValue
    var lastSyncError: String?
    var deletedAt: Date?
    var lastMutationId: String?
    var syncAttemptCount: Int = 0
    var nextRetryAt: Date?
    var localUpdatedAt: Date?

    // MARK: Relationships

    var dailyLog: DailyLogEntity?

    init(
        id: UUID,
        ownerUID: String? = nil,
        dailyLogId: UUID,
        mealTypeRawValue: String?,
        name: String,
        quantity: Double?,
        unit: String?,
        calories: Int,
        protein: Double,
        carbs: Double,
        fat: Double,
        fiber: Double?,
        sodium: Double?,
        sourceRawValue: String,
        confidenceRawValue: String,
        imageUrl: String?,
        notes: String?,
        componentsJSON: String? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.ownerUID = ownerUID
        self.dailyLogId = dailyLogId
        self.mealTypeRawValue = mealTypeRawValue
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.fiber = fiber
        self.sodium = sodium
        self.sourceRawValue = sourceRawValue
        self.confidenceRawValue = confidenceRawValue
        self.imageUrl = imageUrl
        self.notes = notes
        self.componentsJSON = componentsJSON
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
