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

struct MealAdviceAIRequest: Codable, Equatable, Sendable {
    var question: String
    var intentResult: CoachIntentResult?
    var modelTier: CoachModelTier?
    var modelName: String?

    init(
        question: String,
        intentResult: CoachIntentResult? = nil,
        modelTier: CoachModelTier? = nil,
        modelName: String? = nil
    ) {
        self.question = question
        self.intentResult = intentResult
        self.modelTier = modelTier
        self.modelName = modelName
    }
}

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
}

struct AIFoodEstimateResponse: Codable, Equatable, Sendable {
    var foodDrafts: [FoodDraft]
    var confidence: AIConfidence
    var requiresConfirmation: Bool
    var assistantMessage: String?
    var usage: AIUsageMetadata?

    init(
        foodDrafts: [FoodDraft],
        confidence: AIConfidence,
        requiresConfirmation: Bool,
        assistantMessage: String? = nil,
        usage: AIUsageMetadata? = nil
    ) {
        self.foodDrafts = foodDrafts
        self.confidence = confidence
        self.requiresConfirmation = requiresConfirmation
        self.assistantMessage = assistantMessage
        self.usage = usage
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
