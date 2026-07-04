//
//  FoodCorrectionMemoryModels.swift
//  Fitness Coach
//
//  Forma — Local correction memory for Coach food estimates.
//

import Foundation

enum FoodCorrectionType: String, Codable, Equatable, Sendable, CaseIterable {
    case portionAdjustment
    case componentAdded
    case componentRemoved
    case cookingMethodChanged
    case sauceOrOilAdjustment
    case calorieOverride
    case macroAdjustment
    case other
}

enum FoodCorrectionMemorySource: String, Codable, Equatable, Sendable {
    case pendingEditSheet
    case naturalLanguageCorrection
    case postLogEdit
    case photoRecommission
}

struct FoodCorrectionMemoryEntry: Codable, Equatable, Sendable, Identifiable {
    var id: UUID
    var createdAt: Date
    var originalFoodName: String
    var correctedFoodName: String?
    var correctionType: FoodCorrectionType
    var correctionSummary: String
    var beforeCalories: Int?
    var afterCalories: Int?
    var componentName: String?
    var amountHint: String?
    var source: FoodCorrectionMemorySource
    var useCount: Int
    var lastUsedAt: Date?

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        originalFoodName: String,
        correctedFoodName: String? = nil,
        correctionType: FoodCorrectionType,
        correctionSummary: String,
        beforeCalories: Int? = nil,
        afterCalories: Int? = nil,
        componentName: String? = nil,
        amountHint: String? = nil,
        source: FoodCorrectionMemorySource,
        useCount: Int = 1,
        lastUsedAt: Date? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.originalFoodName = originalFoodName
        self.correctedFoodName = correctedFoodName
        self.correctionType = correctionType
        self.correctionSummary = correctionSummary
        self.beforeCalories = beforeCalories
        self.afterCalories = afterCalories
        self.componentName = componentName
        self.amountHint = amountHint
        self.source = source
        self.useCount = useCount
        self.lastUsedAt = lastUsedAt
    }

    var normalizedFoodKey: String {
        CoachContextFoodMemoryBuilder.normalizedFoodName(originalFoodName)
    }

    var mergeKey: String {
        [
            normalizedFoodKey,
            correctionType.rawValue,
            componentName?.lowercased() ?? "",
            amountHint?.lowercased() ?? "",
            correctionSummary.lowercased()
        ].joined(separator: "|")
    }
}

enum FoodCorrectionMemoryLimits {
    static let maxStoredEntries = 50
    static let maxContextEntries = 8
}

struct CoachFoodCorrectionContext: Codable, Equatable, Sendable {
    var patternSummary: String
    var foodKey: String?
    var correctionType: String?
    var componentName: String?
    var amountHint: String?
    var useCount: Int?
    var lastUsedAt: Date?
    var confidence: CoachContextConfidence?

    init(
        patternSummary: String,
        foodKey: String? = nil,
        correctionType: String? = nil,
        componentName: String? = nil,
        amountHint: String? = nil,
        useCount: Int? = nil,
        lastUsedAt: Date? = nil,
        confidence: CoachContextConfidence? = .medium
    ) {
        self.patternSummary = patternSummary
        self.foodKey = foodKey
        self.correctionType = correctionType
        self.componentName = componentName
        self.amountHint = amountHint
        self.useCount = useCount
        self.lastUsedAt = lastUsedAt
        self.confidence = confidence
    }
}
