//
//  CoachIntentResult.swift
//  Fitness Coach
//
//  FitPilot AI — Structured classifier result for the Coach message pipeline.
//

import Foundation

enum CoachModelTier: String, Codable, Equatable, Sendable {
    case cheap
    case strong
}

struct CoachModelConfig: Codable, Equatable, Sendable {
    var cheapClassifierModel: String
    var cheapAnswerModel: String
    var strongCoachModel: String

    nonisolated static let `default` = CoachModelConfig(
        cheapClassifierModel: "gpt-5-nano",
        cheapAnswerModel: "gpt-5-nano",
        strongCoachModel: "gpt-5.4-nano"
    )

    func modelName(for tier: CoachModelTier) -> String {
        switch tier {
        case .cheap:
            return cheapAnswerModel
        case .strong:
            return strongCoachModel
        }
    }
}

enum CoachIntent: String, Codable, Equatable, Sendable {
    case logFood = "log_food"
    case logWater = "log_water"
    case logWeight = "log_weight"
    case logWorkout = "log_workout"
    case editLog = "edit_log"
    case deleteLog = "delete_log"
    case undo
    case dailySummary = "daily_summary"
    case calorieLookup = "calorie_lookup"
    case macroLookup = "macro_lookup"
    case mealDecision = "meal_decision"
    case nutritionAdvice = "nutrition_advice"
    case workoutAdvice = "workout_advice"
    case weightLossAdvice = "weight_loss_advice"
    case appHelp = "app_help"
    case generalConversation = "general_conversation"
    case unrelatedOrUnsupported = "unrelated_or_unsupported"
}

enum CoachIntentDomain: String, Codable, Equatable, Sendable {
    case nutrition
    case fitness
    case hydration
    case bodyMetrics = "body_metrics"
    case app
    case general
    case unrelated
}

struct CoachIntentEntities: Codable, Equatable, Sendable {
    var food: String? = nil
    var meal: String? = nil
    var amountMl: Int? = nil
    var weightKg: Double? = nil
    var durationMinutes: Int? = nil
    var distanceKm: Double? = nil
    var calories: Int? = nil
    var proteinGrams: Double? = nil
    var carbsGrams: Double? = nil
    var fatGrams: Double? = nil
    var quantity: Double? = nil
    var unit: String? = nil
    var notes: String? = nil
}

enum CoachActionType: String, Codable, Equatable, Sendable {
    case logFood = "log_food"
    case logWater = "log_water"
    case logWeight = "log_weight"
    case logWorkout = "log_workout"
    case editLog = "edit_log"
    case deleteLog = "delete_log"
    case undo
    case status
    case dailyReview = "daily_review"
}

enum CoachAction: Equatable, Sendable {
    case logFood(FoodDraft)
    case logWater(WaterDraft)
    case logWeight(WeightDraft)
    case logWorkout(WorkoutDraft)
    case editLog(selector: String?)
    case deleteLog(selector: String?)
    case undo(UndoTarget)
    case status
    case dailyReview
}

extension CoachAction: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case foodDraft
        case waterDraft
        case weightDraft
        case workoutDraft
        case selector
        case undoTarget
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(CoachActionType.self, forKey: .type)

        switch type {
        case .logFood:
            self = .logFood(try container.decode(FoodDraft.self, forKey: .foodDraft))
        case .logWater:
            self = .logWater(try container.decode(WaterDraft.self, forKey: .waterDraft))
        case .logWeight:
            self = .logWeight(try container.decode(WeightDraft.self, forKey: .weightDraft))
        case .logWorkout:
            self = .logWorkout(try container.decode(WorkoutDraft.self, forKey: .workoutDraft))
        case .editLog:
            self = .editLog(selector: try container.decodeIfPresent(String.self, forKey: .selector))
        case .deleteLog:
            self = .deleteLog(selector: try container.decodeIfPresent(String.self, forKey: .selector))
        case .undo:
            self = .undo(try container.decodeIfPresent(UndoTarget.self, forKey: .undoTarget) ?? .last)
        case .status:
            self = .status
        case .dailyReview:
            self = .dailyReview
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .logFood(let draft):
            try container.encode(CoachActionType.logFood, forKey: .type)
            try container.encode(draft, forKey: .foodDraft)
        case .logWater(let draft):
            try container.encode(CoachActionType.logWater, forKey: .type)
            try container.encode(draft, forKey: .waterDraft)
        case .logWeight(let draft):
            try container.encode(CoachActionType.logWeight, forKey: .type)
            try container.encode(draft, forKey: .weightDraft)
        case .logWorkout(let draft):
            try container.encode(CoachActionType.logWorkout, forKey: .type)
            try container.encode(draft, forKey: .workoutDraft)
        case .editLog(let selector):
            try container.encode(CoachActionType.editLog, forKey: .type)
            try container.encodeIfPresent(selector, forKey: .selector)
        case .deleteLog(let selector):
            try container.encode(CoachActionType.deleteLog, forKey: .type)
            try container.encodeIfPresent(selector, forKey: .selector)
        case .undo(let target):
            try container.encode(CoachActionType.undo, forKey: .type)
            try container.encode(target, forKey: .undoTarget)
        case .status:
            try container.encode(CoachActionType.status, forKey: .type)
        case .dailyReview:
            try container.encode(CoachActionType.dailyReview, forKey: .type)
        }
    }
}

struct CoachIntentResult: Codable, Equatable, Sendable {
    var intent: CoachIntent
    var confidence: Double
    var domain: CoachIntentDomain
    var requiresAppMutation: Bool
    var requiresUserContext: Bool
    var canAnswerWithCheapModel: Bool
    var requiresEscalation: Bool
    var entities: CoachIntentEntities
    var action: CoachAction?
    var reason: String?

    private enum CodingKeys: String, CodingKey {
        case intent
        case confidence
        case domain
        case requiresAppMutation
        case requiresUserContext
        case canAnswerWithCheapModel
        case requiresEscalation
        case entities
        case action
        case reason
    }

    init(
        intent: CoachIntent,
        confidence: Double,
        domain: CoachIntentDomain,
        requiresAppMutation: Bool,
        requiresUserContext: Bool,
        canAnswerWithCheapModel: Bool,
        requiresEscalation: Bool,
        entities: CoachIntentEntities = CoachIntentEntities(),
        action: CoachAction? = nil,
        reason: String? = nil
    ) {
        self.intent = intent
        self.confidence = min(max(confidence, 0), 1)
        self.domain = domain
        self.requiresAppMutation = requiresAppMutation
        self.requiresUserContext = requiresUserContext
        self.canAnswerWithCheapModel = canAnswerWithCheapModel
        self.requiresEscalation = requiresEscalation
        self.entities = entities
        self.action = action
        self.reason = reason
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        intent = try container.decode(CoachIntent.self, forKey: .intent)
        confidence = min(max(try container.decodeIfPresent(Double.self, forKey: .confidence) ?? 0.5, 0), 1)
        domain = try container.decode(CoachIntentDomain.self, forKey: .domain)
        requiresAppMutation = try container.decodeIfPresent(Bool.self, forKey: .requiresAppMutation) ?? false
        requiresUserContext = try container.decodeIfPresent(Bool.self, forKey: .requiresUserContext) ?? false
        canAnswerWithCheapModel = try container.decodeIfPresent(Bool.self, forKey: .canAnswerWithCheapModel) ?? true
        requiresEscalation = try container.decodeIfPresent(Bool.self, forKey: .requiresEscalation) ?? false
        entities = try container.decodeIfPresent(CoachIntentEntities.self, forKey: .entities) ?? CoachIntentEntities()

        if container.contains(.action), try container.decodeNil(forKey: .action) == false {
            action = try? container.decode(CoachAction.self, forKey: .action)
        } else {
            action = nil
        }

        reason = try container.decodeIfPresent(String.self, forKey: .reason)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(intent, forKey: .intent)
        try container.encode(confidence, forKey: .confidence)
        try container.encode(domain, forKey: .domain)
        try container.encode(requiresAppMutation, forKey: .requiresAppMutation)
        try container.encode(requiresUserContext, forKey: .requiresUserContext)
        try container.encode(canAnswerWithCheapModel, forKey: .canAnswerWithCheapModel)
        try container.encode(requiresEscalation, forKey: .requiresEscalation)
        try container.encode(entities, forKey: .entities)
        try container.encodeIfPresent(action, forKey: .action)
        try container.encodeIfPresent(reason, forKey: .reason)
    }
}
