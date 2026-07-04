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
    var imageUrl: String?

    // MARK: Estimate trust (additive — optional for backward-compatible decoding)

    var calorieRangeLower: Int?
    var calorieRangeUpper: Int?
    var assumptions: [String]
    var uncertaintyReasons: [String]
    var suggestedClarifications: [String]
    var primaryUncertainty: String?
    var requiresClarificationBeforeLogging: Bool
    var riskLevel: EstimateRiskLevel?
    var componentTrustMetadata: [ComponentEstimateTrustMetadata]

    init(
        id: UUID = UUID(),
        displayName: String,
        mealType: MealType? = nil,
        components: [FoodComponent],
        confidence: ConfidenceLevel = .medium,
        source: FoodEntrySource = .aiTextEstimate,
        notes: String? = nil,
        warnings: [String] = [],
        imageUrl: String? = nil,
        calorieRangeLower: Int? = nil,
        calorieRangeUpper: Int? = nil,
        assumptions: [String] = [],
        uncertaintyReasons: [String] = [],
        suggestedClarifications: [String] = [],
        primaryUncertainty: String? = nil,
        requiresClarificationBeforeLogging: Bool = false,
        riskLevel: EstimateRiskLevel? = nil,
        componentTrustMetadata: [ComponentEstimateTrustMetadata] = []
    ) {
        self.id = id
        self.displayName = displayName
        self.mealType = mealType
        self.components = components
        self.confidence = confidence
        self.source = source
        self.notes = notes
        self.warnings = warnings
        self.imageUrl = imageUrl
        self.calorieRangeLower = calorieRangeLower
        self.calorieRangeUpper = calorieRangeUpper
        self.assumptions = assumptions
        self.uncertaintyReasons = uncertaintyReasons
        self.suggestedClarifications = suggestedClarifications
        self.primaryUncertainty = primaryUncertainty
        self.requiresClarificationBeforeLogging = requiresClarificationBeforeLogging
        self.riskLevel = riskLevel
        self.componentTrustMetadata = componentTrustMetadata
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
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)

        if let nestedRange = try container.decodeIfPresent(CalorieEstimateRange.self, forKey: .calorieRange) {
            calorieRangeLower = nestedRange.lowerBound
            calorieRangeUpper = nestedRange.upperBound
        } else {
            calorieRangeLower = try container.decodeIfPresent(Int.self, forKey: .calorieRangeLower)
                ?? container.decodeIfPresent(Int.self, forKey: .totalCaloriesRangeLower)
            calorieRangeUpper = try container.decodeIfPresent(Int.self, forKey: .calorieRangeUpper)
                ?? container.decodeIfPresent(Int.self, forKey: .totalCaloriesRangeUpper)
        }

        if let nestedTrust = try container.decodeIfPresent(CoachEstimateTrustMetadata.self, forKey: .estimateTrust) {
            assumptions = nestedTrust.assumptions
            uncertaintyReasons = nestedTrust.uncertaintyReasons
            suggestedClarifications = nestedTrust.suggestedClarifications
            primaryUncertainty = nestedTrust.primaryUncertainty
            requiresClarificationBeforeLogging = nestedTrust.requiresClarificationBeforeLogging
            riskLevel = nestedTrust.riskLevel
            if let nestedConfidence = Optional(nestedTrust.confidence) {
                confidence = nestedConfidence
            }
        } else {
            assumptions = try container.decodeIfPresent([String].self, forKey: .assumptions) ?? []
            uncertaintyReasons = try container.decodeIfPresent([String].self, forKey: .uncertaintyReasons) ?? []
            suggestedClarifications = try container.decodeIfPresent([String].self, forKey: .suggestedClarifications) ?? []
            primaryUncertainty = try container.decodeIfPresent(String.self, forKey: .primaryUncertainty)
            requiresClarificationBeforeLogging = try container.decodeIfPresent(Bool.self, forKey: .requiresClarificationBeforeLogging) ?? false
            riskLevel = try container.decodeIfPresent(EstimateRiskLevel.self, forKey: .riskLevel)
        }

        componentTrustMetadata = try container.decodeIfPresent([ComponentEstimateTrustMetadata].self, forKey: .componentTrustMetadata) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(displayName, forKey: .displayName)
        try container.encodeIfPresent(mealType?.rawValue, forKey: .mealType)
        try container.encode(components, forKey: .components)
        try container.encode(confidence, forKey: .confidence)
        try container.encode(source, forKey: .source)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encode(warnings, forKey: .warnings)
        try container.encodeIfPresent(imageUrl, forKey: .imageUrl)
        try container.encodeIfPresent(calorieRangeLower, forKey: .calorieRangeLower)
        try container.encodeIfPresent(calorieRangeUpper, forKey: .calorieRangeUpper)
        try container.encode(assumptions, forKey: .assumptions)
        try container.encode(uncertaintyReasons, forKey: .uncertaintyReasons)
        try container.encode(suggestedClarifications, forKey: .suggestedClarifications)
        try container.encodeIfPresent(primaryUncertainty, forKey: .primaryUncertainty)
        try container.encode(requiresClarificationBeforeLogging, forKey: .requiresClarificationBeforeLogging)
        try container.encodeIfPresent(riskLevel, forKey: .riskLevel)
        if !componentTrustMetadata.isEmpty {
            try container.encode(componentTrustMetadata, forKey: .componentTrustMetadata)
        }
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
        case imageUrl
        case calorieRange
        case calorieRangeLower
        case calorieRangeUpper
        case totalCaloriesRangeLower
        case totalCaloriesRangeUpper
        case assumptions
        case uncertaintyReasons
        case suggestedClarifications
        case primaryUncertainty
        case requiresClarificationBeforeLogging
        case riskLevel
        case estimateTrust
        case componentTrustMetadata
    }
}
