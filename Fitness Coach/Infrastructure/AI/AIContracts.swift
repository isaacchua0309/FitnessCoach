//
//  AIContracts.swift
//  Fitness Coach
//
//  FitPilot AI — Request/response contracts for the future backend AI gateway.
//
//  These are transport-shaped Codable types. The production iOS app will call a
//  FitPilot backend AI gateway (not a raw LLM provider), so no provider API keys
//  live in the app.
//

import Foundation

// MARK: Supporting Inputs

struct DailyReviewAIInput: Codable, Equatable, Sendable {
    var date: Date
    var calorieTarget: Int
    var caloriesConsumed: Int
    var caloriesRemaining: Int
    var isOverCalorieTarget: Bool
    var proteinTarget: Double
    var proteinConsumed: Double
    var proteinRemaining: Double
    var hasMetProteinTarget: Bool
    var carbsTarget: Double
    var carbsConsumed: Double
    var carbsRemaining: Double
    var fatTarget: Double
    var fatConsumed: Double
    var fatRemaining: Double
    var waterTargetMl: Int
    var waterConsumedMl: Int
    var waterRemainingMl: Int
    var hasMetWaterTarget: Bool
    var weightKg: Double?
    var latestWeightKg: Double?
    var steps: Int?
    var workoutCount: Int
    var workoutCaloriesBurned: Int
    var foodEntryCount: Int
    var lowConfidenceFoodCount: Int
    var topProteinFoodNames: [String]
    var deterministicNotes: [String]
}

// MARK: Parse Command

struct AIParseCommandRequest: Codable, Equatable, Sendable {
    var text: String
    var context: AIContext
}

struct AIParseCommandResponse: Codable, Equatable, Sendable {
    var parsedCommand: AIParsedCommand
    var usage: AIUsageMetadata?

    init(parsedCommand: AIParsedCommand, usage: AIUsageMetadata? = nil) {
        self.parsedCommand = parsedCommand
        self.usage = usage
    }
}

// MARK: Intent Classification

struct AICoachIntentClassificationRequest: Codable, Equatable, Sendable {
    var text: String
    var context: AIContext
    var modelName: String
    var modelConfig: CoachModelConfig
}

struct AICoachIntentClassificationResponse: Codable, Equatable, Sendable {
    var intentResult: CoachIntentResult
    var usage: AIUsageMetadata?

    init(intentResult: CoachIntentResult, usage: AIUsageMetadata? = nil) {
        self.intentResult = intentResult
        self.usage = usage
    }
}

// MARK: Food Estimate

struct AIFoodEstimateRequest: Codable, Equatable, Sendable {
    var text: String
    var context: AIContext
    /// Base64-encoded JPEG sent for vision-based meal analysis.
    var imageJPEGBase64: String?
    /// When set, backend/appends stricter repair instructions after a failed validation pass.
    var repairErrors: [String]?

    init(
        text: String,
        context: AIContext,
        imageJPEGBase64: String? = nil,
        repairErrors: [String]? = nil
    ) {
        self.text = text
        self.context = context
        self.imageJPEGBase64 = imageJPEGBase64
        self.repairErrors = repairErrors
    }
}

struct AIFoodEstimateResponse: Codable, Equatable, Sendable {
    var foodLogDrafts: [FoodLogDraft]
    /// Legacy single-item drafts retained for backward-compatible API decoding.
    var foodDrafts: [FoodDraft]
    var confidence: AIConfidence
    var requiresConfirmation: Bool
    var assistantMessage: String?
    var usage: AIUsageMetadata?

    init(
        foodLogDrafts: [FoodLogDraft],
        foodDrafts: [FoodDraft] = [],
        confidence: AIConfidence,
        requiresConfirmation: Bool,
        assistantMessage: String? = nil,
        usage: AIUsageMetadata? = nil
    ) {
        self.foodLogDrafts = foodLogDrafts
        self.foodDrafts = foodDrafts.isEmpty
            ? foodLogDrafts.map(FoodLogDraftMapper.toLegacyDraft)
            : foodDrafts
        self.confidence = confidence
        self.requiresConfirmation = requiresConfirmation
        self.assistantMessage = assistantMessage
        self.usage = usage
    }

    init(
        foodDrafts: [FoodDraft],
        confidence: AIConfidence,
        requiresConfirmation: Bool,
        assistantMessage: String? = nil,
        usage: AIUsageMetadata? = nil
    ) {
        self.foodLogDrafts = foodDrafts.map(FoodLogDraftMapper.fromLegacyDraft)
        self.foodDrafts = foodDrafts
        self.confidence = confidence
        self.requiresConfirmation = requiresConfirmation
        self.assistantMessage = assistantMessage
        self.usage = usage
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedLogDrafts = try container.decodeIfPresent([FoodLogDraft].self, forKey: .foodLogDrafts) ?? []
        let decodedDrafts = try container.decodeIfPresent([FoodDraft].self, forKey: .foodDrafts) ?? []
        confidence = try container.decode(AIConfidence.self, forKey: .confidence)
        requiresConfirmation = try container.decode(Bool.self, forKey: .requiresConfirmation)
        assistantMessage = try container.decodeIfPresent(String.self, forKey: .assistantMessage)
        usage = try container.decodeIfPresent(AIUsageMetadata.self, forKey: .usage)

        if !decodedLogDrafts.isEmpty {
            foodLogDrafts = decodedLogDrafts
            foodDrafts = decodedDrafts.isEmpty
                ? decodedLogDrafts.map(FoodLogDraftMapper.toLegacyDraft)
                : decodedDrafts
        } else {
            foodDrafts = decodedDrafts
            foodLogDrafts = decodedDrafts.map(FoodLogDraftMapper.fromLegacyDraft)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(foodLogDrafts, forKey: .foodLogDrafts)
        try container.encode(foodDrafts, forKey: .foodDrafts)
        try container.encode(confidence, forKey: .confidence)
        try container.encode(requiresConfirmation, forKey: .requiresConfirmation)
        try container.encodeIfPresent(assistantMessage, forKey: .assistantMessage)
        try container.encodeIfPresent(usage, forKey: .usage)
    }

    private enum CodingKeys: String, CodingKey {
        case foodLogDrafts
        case foodDrafts
        case confidence
        case requiresConfirmation
        case assistantMessage
        case usage
    }
}

// MARK: Meal Advice

struct AIMealAdviceRequest: Codable, Equatable, Sendable {
    var question: String
    var context: AIContext
    var intentResult: CoachIntentResult?
    var modelTier: CoachModelTier?
    var modelName: String?

    init(
        question: String,
        context: AIContext,
        intentResult: CoachIntentResult? = nil,
        modelTier: CoachModelTier? = nil,
        modelName: String? = nil
    ) {
        self.question = question
        self.context = context
        self.intentResult = intentResult
        self.modelTier = modelTier
        self.modelName = modelName
    }
}

struct AIMealAdviceResponse: Codable, Equatable, Sendable {
    var response: AICoachResponse
    var usage: AIUsageMetadata?

    init(response: AICoachResponse, usage: AIUsageMetadata? = nil) {
        self.response = response
        self.usage = usage
    }
}

// MARK: Daily Review

struct AIDailyReviewRequest: Codable, Equatable, Sendable {
    var input: DailyReviewAIInput
    var context: AIContext
}

struct AIDailyReviewResponse: Codable, Equatable, Sendable {
    var response: AICoachResponse
    var usage: AIUsageMetadata?

    init(response: AICoachResponse, usage: AIUsageMetadata? = nil) {
        self.response = response
        self.usage = usage
    }
}

// MARK: Workout Parse

struct AIWorkoutParseRequest: Codable, Equatable, Sendable {
    var text: String
    var context: AIContext
}

struct AIWorkoutParseResponse: Codable, Equatable, Sendable {
    var workoutDraft: WorkoutDraft
    var assistantMessage: String?
    var confidence: AIConfidence
    var usage: AIUsageMetadata?

    init(
        workoutDraft: WorkoutDraft,
        assistantMessage: String? = nil,
        confidence: AIConfidence,
        usage: AIUsageMetadata? = nil
    ) {
        self.workoutDraft = workoutDraft
        self.assistantMessage = assistantMessage
        self.confidence = confidence
        self.usage = usage
    }
}

// MARK: Edit / Delete Parse

struct AIEditDeleteParseRequest: Codable, Equatable, Sendable {
    var text: String
    var context: AIContext
}

struct AIEditDeleteParseResponse: Codable, Equatable, Sendable {
    var parsedCommand: AIParsedCommand
    var usage: AIUsageMetadata?

    init(parsedCommand: AIParsedCommand, usage: AIUsageMetadata? = nil) {
        self.parsedCommand = parsedCommand
        self.usage = usage
    }
}

// MARK: Multi Action Parse

struct AIMultiActionParseRequest: Codable, Equatable, Sendable {
    var text: String
    var context: AIContext
}

struct AIMultiActionParseResponse: Codable, Equatable, Sendable {
    var parsedCommand: AIParsedCommand
    var usage: AIUsageMetadata?

    init(parsedCommand: AIParsedCommand, usage: AIUsageMetadata? = nil) {
        self.parsedCommand = parsedCommand
        self.usage = usage
    }
}
