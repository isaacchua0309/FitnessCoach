//
//  NutritionEstimateModels.swift
//  Fitness Coach
//
//  Forma — Structured nutrition estimate and comparison responses for Coach cards.
//

import Foundation

// MARK: - Suggested actions

enum NutritionSuggestedActionType: String, Codable, Equatable, Sendable {
    case logMeal = "logMeal"
    case estimateAnother = "estimateAnother"
    case addCommonSide = "addCommonSide"
    case addDrink = "addDrink"
    case compareAlternative = "compareAlternative"
    case healthierAlternative = "healthierAlternative"
    case askFollowUp = "askFollowUp"
}

struct NutritionSuggestedAction: Codable, Equatable, Sendable, Identifiable {
    var id: String
    var title: String
    var type: NutritionSuggestedActionType
    var payload: [String: String]

    init(
        id: String = UUID().uuidString,
        title: String,
        type: NutritionSuggestedActionType,
        payload: [String: String] = [:]
    ) {
        self.id = id
        self.title = title
        self.type = type
        self.payload = payload
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        title = try container.decode(String.self, forKey: .title)
        type = try container.decode(NutritionSuggestedActionType.self, forKey: .type)
        payload = Self.decodePayload(from: container)
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, type, payload
    }

    /// Decodes strict-schema payload objects that include nullable string keys.
    private static func decodePayload(
        from container: KeyedDecodingContainer<CodingKeys>
    ) -> [String: String] {
        let rawPayload: [String: String?]?
        do {
            rawPayload = try container.decodeIfPresent([String: String?].self, forKey: .payload)
        } catch {
            return [:]
        }
        guard let rawPayload else { return [:] }

        return rawPayload.reduce(into: [String: String]()) { result, entry in
            guard let value = entry.value else { return }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed.lowercased() != "null" else { return }
            result[entry.key] = trimmed
        }
    }
}

// MARK: - Transport responses

enum NutritionEstimateSourceType: String, Codable, Equatable, Sendable {
    case branded
    case common
    case restaurant
    case homemade
    case unknown
}

struct NutritionEstimateResponse: Codable, Equatable, Sendable {
    var type: String
    var foodName: String
    var displayEmoji: String?
    var caloriesKcal: Int?
    var caloriesRangeLowerKcal: Int?
    var caloriesRangeUpperKcal: Int?
    var proteinGrams: Double?
    var carbsGrams: Double?
    var fatGrams: Double?
    var servingDescription: String?
    var confidenceLevel: AIConfidence
    var confidenceLabel: String?
    var confidenceReason: String?
    var sourceType: NutritionEstimateSourceType?
    var todayCaloriesTarget: Int?
    var todayCaloriesConsumed: Int?
    var todayCaloriesRemainingAfterEstimate: Int?
    var todayProteinTarget: Double?
    var todayProteinConsumed: Double?
    var todayProteinRemainingAfterEstimate: Double?
    var coachSummary: String?
    var coachTip: String?
    var caveats: [String]
    var suggestedActions: [NutritionSuggestedAction]
    var assumptions: [String]
    var uncertaintyReasons: [String]
    var suggestedClarifications: [String]
    var primaryUncertainty: String?
    var requiresClarificationBeforeLogging: Bool
    var riskLevel: EstimateRiskLevel?

    init(
        type: String = "nutrition_estimate",
        foodName: String,
        displayEmoji: String? = nil,
        caloriesKcal: Int? = nil,
        caloriesRangeLowerKcal: Int? = nil,
        caloriesRangeUpperKcal: Int? = nil,
        proteinGrams: Double? = nil,
        carbsGrams: Double? = nil,
        fatGrams: Double? = nil,
        servingDescription: String? = nil,
        confidenceLevel: AIConfidence = .medium,
        confidenceLabel: String? = nil,
        confidenceReason: String? = nil,
        sourceType: NutritionEstimateSourceType? = nil,
        todayCaloriesTarget: Int? = nil,
        todayCaloriesConsumed: Int? = nil,
        todayCaloriesRemainingAfterEstimate: Int? = nil,
        todayProteinTarget: Double? = nil,
        todayProteinConsumed: Double? = nil,
        todayProteinRemainingAfterEstimate: Double? = nil,
        coachSummary: String? = nil,
        coachTip: String? = nil,
        caveats: [String] = [],
        suggestedActions: [NutritionSuggestedAction] = [],
        assumptions: [String] = [],
        uncertaintyReasons: [String] = [],
        suggestedClarifications: [String] = [],
        primaryUncertainty: String? = nil,
        requiresClarificationBeforeLogging: Bool = false,
        riskLevel: EstimateRiskLevel? = nil
    ) {
        self.type = type
        self.foodName = foodName
        self.displayEmoji = displayEmoji
        self.caloriesKcal = caloriesKcal
        self.caloriesRangeLowerKcal = caloriesRangeLowerKcal
        self.caloriesRangeUpperKcal = caloriesRangeUpperKcal
        self.proteinGrams = proteinGrams
        self.carbsGrams = carbsGrams
        self.fatGrams = fatGrams
        self.servingDescription = servingDescription
        self.confidenceLevel = confidenceLevel
        self.confidenceLabel = confidenceLabel
        self.confidenceReason = confidenceReason
        self.sourceType = sourceType
        self.todayCaloriesTarget = todayCaloriesTarget
        self.todayCaloriesConsumed = todayCaloriesConsumed
        self.todayCaloriesRemainingAfterEstimate = todayCaloriesRemainingAfterEstimate
        self.todayProteinTarget = todayProteinTarget
        self.todayProteinConsumed = todayProteinConsumed
        self.todayProteinRemainingAfterEstimate = todayProteinRemainingAfterEstimate
        self.coachSummary = coachSummary
        self.coachTip = coachTip
        self.caveats = caveats
        self.suggestedActions = suggestedActions
        self.assumptions = assumptions
        self.uncertaintyReasons = uncertaintyReasons
        self.suggestedClarifications = suggestedClarifications
        self.primaryUncertainty = primaryUncertainty
        self.requiresClarificationBeforeLogging = requiresClarificationBeforeLogging
        self.riskLevel = riskLevel
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? "nutrition_estimate"
        foodName = try container.decode(String.self, forKey: .foodName)
        displayEmoji = try container.decodeIfPresent(String.self, forKey: .displayEmoji)
        caloriesKcal = try container.decodeIfPresent(Int.self, forKey: .caloriesKcal)
        caloriesRangeLowerKcal = try container.decodeIfPresent(Int.self, forKey: .caloriesRangeLowerKcal)
        caloriesRangeUpperKcal = try container.decodeIfPresent(Int.self, forKey: .caloriesRangeUpperKcal)
        proteinGrams = try container.decodeIfPresent(Double.self, forKey: .proteinGrams)
        carbsGrams = try container.decodeIfPresent(Double.self, forKey: .carbsGrams)
        fatGrams = try container.decodeIfPresent(Double.self, forKey: .fatGrams)
        servingDescription = try container.decodeIfPresent(String.self, forKey: .servingDescription)
        confidenceLevel = try container.decodeIfPresent(AIConfidence.self, forKey: .confidenceLevel) ?? .medium
        confidenceLabel = try container.decodeIfPresent(String.self, forKey: .confidenceLabel)
        confidenceReason = try container.decodeIfPresent(String.self, forKey: .confidenceReason)
        sourceType = try container.decodeIfPresent(NutritionEstimateSourceType.self, forKey: .sourceType)
        todayCaloriesTarget = try container.decodeIfPresent(Int.self, forKey: .todayCaloriesTarget)
        todayCaloriesConsumed = try container.decodeIfPresent(Int.self, forKey: .todayCaloriesConsumed)
        todayCaloriesRemainingAfterEstimate = try container.decodeIfPresent(Int.self, forKey: .todayCaloriesRemainingAfterEstimate)
        todayProteinTarget = try container.decodeIfPresent(Double.self, forKey: .todayProteinTarget)
        todayProteinConsumed = try container.decodeIfPresent(Double.self, forKey: .todayProteinConsumed)
        todayProteinRemainingAfterEstimate = try container.decodeIfPresent(Double.self, forKey: .todayProteinRemainingAfterEstimate)
        coachSummary = try container.decodeIfPresent(String.self, forKey: .coachSummary)
        coachTip = try container.decodeIfPresent(String.self, forKey: .coachTip)
        caveats = try container.decodeIfPresent([String].self, forKey: .caveats) ?? []
        suggestedActions = try container.decodeIfPresent([NutritionSuggestedAction].self, forKey: .suggestedActions) ?? []
        assumptions = try container.decodeIfPresent([String].self, forKey: .assumptions) ?? []
        uncertaintyReasons = try container.decodeIfPresent([String].self, forKey: .uncertaintyReasons) ?? []
        suggestedClarifications = try container.decodeIfPresent([String].self, forKey: .suggestedClarifications) ?? []
        primaryUncertainty = try container.decodeIfPresent(String.self, forKey: .primaryUncertainty)
        requiresClarificationBeforeLogging = try container.decodeIfPresent(Bool.self, forKey: .requiresClarificationBeforeLogging) ?? false
        riskLevel = try container.decodeIfPresent(EstimateRiskLevel.self, forKey: .riskLevel)
    }

    private enum CodingKeys: String, CodingKey {
        case type, foodName, displayEmoji, caloriesKcal, caloriesRangeLowerKcal, caloriesRangeUpperKcal
        case proteinGrams, carbsGrams, fatGrams, servingDescription, confidenceLevel, confidenceLabel
        case confidenceReason, sourceType, todayCaloriesTarget, todayCaloriesConsumed
        case todayCaloriesRemainingAfterEstimate, todayProteinTarget, todayProteinConsumed
        case todayProteinRemainingAfterEstimate, coachSummary, coachTip, caveats, suggestedActions
        case assumptions, uncertaintyReasons, suggestedClarifications, primaryUncertainty
        case requiresClarificationBeforeLogging, riskLevel
    }
}

struct NutritionComparisonItem: Codable, Equatable, Sendable, Identifiable {
    var id: String
    var foodName: String
    var displayEmoji: String?
    var caloriesKcal: Int?
    var caloriesRangeLowerKcal: Int?
    var caloriesRangeUpperKcal: Int?
    var proteinGrams: Double?
    var carbsGrams: Double?
    var fatGrams: Double?
    var servingDescription: String?

    init(
        id: String = UUID().uuidString,
        foodName: String,
        displayEmoji: String? = nil,
        caloriesKcal: Int? = nil,
        caloriesRangeLowerKcal: Int? = nil,
        caloriesRangeUpperKcal: Int? = nil,
        proteinGrams: Double? = nil,
        carbsGrams: Double? = nil,
        fatGrams: Double? = nil,
        servingDescription: String? = nil
    ) {
        self.id = id
        self.foodName = foodName
        self.displayEmoji = displayEmoji
        self.caloriesKcal = caloriesKcal
        self.caloriesRangeLowerKcal = caloriesRangeLowerKcal
        self.caloriesRangeUpperKcal = caloriesRangeUpperKcal
        self.proteinGrams = proteinGrams
        self.carbsGrams = carbsGrams
        self.fatGrams = fatGrams
        self.servingDescription = servingDescription
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        foodName = try container.decode(String.self, forKey: .foodName)
        displayEmoji = try container.decodeIfPresent(String.self, forKey: .displayEmoji)
        caloriesKcal = try container.decodeIfPresent(Int.self, forKey: .caloriesKcal)
        caloriesRangeLowerKcal = try container.decodeIfPresent(Int.self, forKey: .caloriesRangeLowerKcal)
        caloriesRangeUpperKcal = try container.decodeIfPresent(Int.self, forKey: .caloriesRangeUpperKcal)
        proteinGrams = try container.decodeIfPresent(Double.self, forKey: .proteinGrams)
        carbsGrams = try container.decodeIfPresent(Double.self, forKey: .carbsGrams)
        fatGrams = try container.decodeIfPresent(Double.self, forKey: .fatGrams)
        servingDescription = try container.decodeIfPresent(String.self, forKey: .servingDescription)
    }
}

struct NutritionComparisonResponse: Codable, Equatable, Sendable {
    var type: String
    var leftItem: NutritionComparisonItem
    var rightItem: NutritionComparisonItem
    var coachPick: String?
    var suggestedActions: [NutritionSuggestedAction]

    init(
        type: String = "nutrition_comparison",
        leftItem: NutritionComparisonItem,
        rightItem: NutritionComparisonItem,
        coachPick: String? = nil,
        suggestedActions: [NutritionSuggestedAction] = []
    ) {
        self.type = type
        self.leftItem = leftItem
        self.rightItem = rightItem
        self.coachPick = coachPick
        self.suggestedActions = suggestedActions
    }
}

// MARK: - UI display state

struct NutritionEstimateTodayContext: Equatable, Sendable, Codable {
    var caloriesAfterLine: String
    var caloriesRemainingLine: String
    var proteinLine: String
}

struct NutritionEstimateCardState: Equatable, Sendable, Identifiable, Codable {
    let id: UUID
    var foodName: String
    var displayEmoji: String?
    var servingDescription: String?
    var caloriesDisplay: String
    var proteinDisplay: String?
    var carbsDisplay: String?
    var fatDisplay: String?
    var confidenceTitle: String
    var confidenceSubtitle: String?
    var coachSummary: String?
    var coachTip: String?
    var caveats: [String]
    var todayContext: NutritionEstimateTodayContext?
    var suggestedActions: [NutritionSuggestedAction]
    var sourceType: NutritionEstimateSourceType?
    var confidenceLevel: AIConfidence
    var hasMacros: Bool
    var hasTodayContext: Bool
    var logMealPayload: NutritionSuggestedAction?
    var calorieRange: CalorieEstimateRange?
    var estimateTrust: CoachEstimateTrustMetadata?

    init(
        id: UUID,
        foodName: String,
        displayEmoji: String? = nil,
        servingDescription: String? = nil,
        caloriesDisplay: String,
        proteinDisplay: String? = nil,
        carbsDisplay: String? = nil,
        fatDisplay: String? = nil,
        confidenceTitle: String,
        confidenceSubtitle: String? = nil,
        coachSummary: String? = nil,
        coachTip: String? = nil,
        caveats: [String] = [],
        todayContext: NutritionEstimateTodayContext? = nil,
        suggestedActions: [NutritionSuggestedAction] = [],
        sourceType: NutritionEstimateSourceType? = nil,
        confidenceLevel: AIConfidence = .medium,
        hasMacros: Bool = false,
        hasTodayContext: Bool = false,
        logMealPayload: NutritionSuggestedAction? = nil,
        calorieRange: CalorieEstimateRange? = nil,
        estimateTrust: CoachEstimateTrustMetadata? = nil
    ) {
        self.id = id
        self.foodName = foodName
        self.displayEmoji = displayEmoji
        self.servingDescription = servingDescription
        self.caloriesDisplay = caloriesDisplay
        self.proteinDisplay = proteinDisplay
        self.carbsDisplay = carbsDisplay
        self.fatDisplay = fatDisplay
        self.confidenceTitle = confidenceTitle
        self.confidenceSubtitle = confidenceSubtitle
        self.coachSummary = coachSummary
        self.coachTip = coachTip
        self.caveats = caveats
        self.todayContext = todayContext
        self.suggestedActions = suggestedActions
        self.sourceType = sourceType
        self.confidenceLevel = confidenceLevel
        self.hasMacros = hasMacros
        self.hasTodayContext = hasTodayContext
        self.logMealPayload = logMealPayload
        self.calorieRange = calorieRange
        self.estimateTrust = estimateTrust
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        foodName = try container.decode(String.self, forKey: .foodName)
        displayEmoji = try container.decodeIfPresent(String.self, forKey: .displayEmoji)
        servingDescription = try container.decodeIfPresent(String.self, forKey: .servingDescription)
        caloriesDisplay = try container.decode(String.self, forKey: .caloriesDisplay)
        proteinDisplay = try container.decodeIfPresent(String.self, forKey: .proteinDisplay)
        carbsDisplay = try container.decodeIfPresent(String.self, forKey: .carbsDisplay)
        fatDisplay = try container.decodeIfPresent(String.self, forKey: .fatDisplay)
        confidenceTitle = try container.decode(String.self, forKey: .confidenceTitle)
        confidenceSubtitle = try container.decodeIfPresent(String.self, forKey: .confidenceSubtitle)
        coachSummary = try container.decodeIfPresent(String.self, forKey: .coachSummary)
        coachTip = try container.decodeIfPresent(String.self, forKey: .coachTip)
        caveats = try container.decodeIfPresent([String].self, forKey: .caveats) ?? []
        todayContext = try container.decodeIfPresent(NutritionEstimateTodayContext.self, forKey: .todayContext)
        suggestedActions = try container.decodeIfPresent([NutritionSuggestedAction].self, forKey: .suggestedActions) ?? []
        sourceType = try container.decodeIfPresent(NutritionEstimateSourceType.self, forKey: .sourceType)
        confidenceLevel = try container.decodeIfPresent(AIConfidence.self, forKey: .confidenceLevel) ?? .medium
        hasMacros = try container.decodeIfPresent(Bool.self, forKey: .hasMacros) ?? false
        hasTodayContext = try container.decodeIfPresent(Bool.self, forKey: .hasTodayContext) ?? false
        logMealPayload = try container.decodeIfPresent(NutritionSuggestedAction.self, forKey: .logMealPayload)
        calorieRange = try container.decodeIfPresent(CalorieEstimateRange.self, forKey: .calorieRange)
        estimateTrust = try container.decodeIfPresent(CoachEstimateTrustMetadata.self, forKey: .estimateTrust)
    }

    private enum CodingKeys: String, CodingKey {
        case id, foodName, displayEmoji, servingDescription, caloriesDisplay, proteinDisplay, carbsDisplay, fatDisplay
        case confidenceTitle, confidenceSubtitle, coachSummary, coachTip, caveats, todayContext, suggestedActions
        case sourceType, confidenceLevel, hasMacros, hasTodayContext, logMealPayload, calorieRange, estimateTrust
    }
}

struct NutritionComparisonCardState: Equatable, Sendable, Identifiable, Codable {
    let id: UUID
    var leftItem: NutritionComparisonItem
    var rightItem: NutritionComparisonItem
    var leftCaloriesDisplay: String
    var rightCaloriesDisplay: String
    var leftProteinDisplay: String?
    var rightProteinDisplay: String?
    var leftFatDisplay: String?
    var rightFatDisplay: String?
    var coachPick: String?
    var suggestedActions: [NutritionSuggestedAction]
}

// MARK: - Chat structured content

enum CoachStructuredMessageContent: Codable, Equatable, Sendable {
    case nutritionEstimate(NutritionEstimateCardState)
    case nutritionComparison(NutritionComparisonCardState)

    private enum CodingKeys: String, CodingKey {
        case type
        case estimate
        case comparison
    }

    private enum ContentType: String, Codable {
        case nutritionEstimate
        case nutritionComparison
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ContentType.self, forKey: .type)
        switch type {
        case .nutritionEstimate:
            self = .nutritionEstimate(try container.decode(NutritionEstimateCardState.self, forKey: .estimate))
        case .nutritionComparison:
            self = .nutritionComparison(try container.decode(NutritionComparisonCardState.self, forKey: .comparison))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .nutritionEstimate(let state):
            try container.encode(ContentType.nutritionEstimate, forKey: .type)
            try container.encode(state, forKey: .estimate)
        case .nutritionComparison(let state):
            try container.encode(ContentType.nutritionComparison, forKey: .type)
            try container.encode(state, forKey: .comparison)
        }
    }
}
