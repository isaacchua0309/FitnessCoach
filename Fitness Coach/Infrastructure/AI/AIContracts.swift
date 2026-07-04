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
    var context: CoachContextPacketV2
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
    var context: CoachContextPacketV2
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
    var context: CoachContextPacketV2
    /// Base64-encoded JPEG sent for vision-based meal analysis.
    var imageJPEGBase64: String?
    /// When set, backend/appends stricter repair instructions after a failed validation pass.
    var repairErrors: [String]?

    init(
        text: String,
        context: CoachContextPacketV2,
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
    var context: CoachContextPacketV2
    var intentResult: CoachIntentResult?
    var modelTier: CoachModelTier?
    var modelName: String?

    init(
        question: String,
        context: CoachContextPacketV2,
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

// MARK: Nutrition Estimate

struct AINutritionEstimateRequest: Codable, Equatable, Sendable {
    var question: String
    var context: CoachContextPacketV2
    var intentResult: CoachIntentResult?
    var modelTier: CoachModelTier?
    var modelName: String?

    init(
        question: String,
        context: CoachContextPacketV2,
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

struct AINutritionEstimateResponse: Codable, Equatable, Sendable {
    var estimate: NutritionEstimateResponse
    var usage: AIUsageMetadata?

    init(estimate: NutritionEstimateResponse, usage: AIUsageMetadata? = nil) {
        self.estimate = estimate
        self.usage = usage
    }
}

// MARK: Nutrition Comparison

struct AINutritionComparisonRequest: Codable, Equatable, Sendable {
    var question: String
    var context: CoachContextPacketV2
    var intentResult: CoachIntentResult?
    var modelTier: CoachModelTier?
    var modelName: String?

    init(
        question: String,
        context: CoachContextPacketV2,
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

struct AINutritionComparisonResponse: Codable, Equatable, Sendable {
    var comparison: NutritionComparisonResponse
    var usage: AIUsageMetadata?

    init(comparison: NutritionComparisonResponse, usage: AIUsageMetadata? = nil) {
        self.comparison = comparison
        self.usage = usage
    }
}

// MARK: Daily Review

struct AIDailyReviewRequest: Codable, Equatable, Sendable {
    var input: DailyReviewAIInput
    var context: CoachContextPacketV2
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
    var context: CoachContextPacketV2
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
    var context: CoachContextPacketV2
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
    var context: CoachContextPacketV2
}

struct AIMultiActionParseResponse: Codable, Equatable, Sendable {
    var parsedCommand: AIParsedCommand
    var usage: AIUsageMetadata?

    init(parsedCommand: AIParsedCommand, usage: AIUsageMetadata? = nil) {
        self.parsedCommand = parsedCommand
        self.usage = usage
    }
}

// MARK: Meal Image Analysis

struct AIMealImagePayload: Codable, Equatable, Sendable {
    var mimeType: String
    var base64: String
    var filename: String?
    var width: Int?
    var height: Int?

    /// Default gateway filename for compressed Coach meal-photo uploads.
    static let defaultUploadFilename = "coach-image.jpg"

    /// Builds a gateway payload from pipeline-compressed upload bytes.
    /// Base64 encodes only `uploadData` — never a full-resolution original.
    static func fromCompressedUpload(
        _ uploadData: Data,
        mimeType: String = CoachImageUploadConfig.default.mimeType,
        filename: String = defaultUploadFilename,
        processedSize: CoachImagePixelSize? = nil
    ) -> AIMealImagePayload {
        AIMealImagePayload(
            mimeType: mimeType,
            base64: uploadData.base64EncodedString(),
            filename: filename,
            width: processedSize?.width,
            height: processedSize?.height
        )
    }

    static func jpeg(_ data: Data, width: Int? = nil, height: Int? = nil) -> AIMealImagePayload {
        let processedSize: CoachImagePixelSize?
        if let width, let height {
            processedSize = CoachImagePixelSize(width: width, height: height)
        } else {
            processedSize = nil
        }
        return fromCompressedUpload(data, processedSize: processedSize)
    }
}

struct AIMealImageAnalysisPreviousItem: Codable, Equatable, Sendable {
    var name: String
    var quantity: String?
    var calories: Int
    var protein: Double
    var carbs: Double
    var fat: Double
    var confidence: AIConfidence
    var assumptions: [String]
}

struct AIMealImageAnalysisPreviousAnalysis: Codable, Equatable, Sendable {
    var summary: String
    var items: [AIMealImageAnalysisPreviousItem]
    var total: AIMealImageAnalysisTotals
}

struct AIMealImageAnalysisTotals: Codable, Equatable, Sendable {
    var calories: Int
    var protein: Double
    var carbs: Double
    var fat: Double
}

struct AIMealImageAnalysisRequest: Codable, Equatable, Sendable {
    var message: String?
    var context: CoachContextPacketV2
    var image: AIMealImagePayload
    var locale: String?
    var userContext: [String: String]?
    var clarification: String?
    var previousAnalysis: AIMealImageAnalysisPreviousAnalysis?

    init(
        message: String? = nil,
        context: CoachContextPacketV2,
        image: AIMealImagePayload,
        locale: String? = nil,
        userContext: [String: String]? = nil,
        clarification: String? = nil,
        previousAnalysis: AIMealImageAnalysisPreviousAnalysis? = nil
    ) {
        self.message = message
        self.context = context
        self.image = image
        self.locale = locale
        self.userContext = userContext
        self.clarification = clarification
        self.previousAnalysis = previousAnalysis
    }
}

struct AIMealImageAnalysisItem: Codable, Equatable, Sendable {
    var name: String
    var quantity: String?
    var calories: Int
    var protein: Double
    var carbs: Double
    var fat: Double
    var confidence: AIConfidence
    var assumptions: [String]
}

struct AIMealImageAnalysisResponse: Codable, Equatable, Sendable {
    var summary: String
    var items: [AIMealImageAnalysisItem]
    var total: AIMealImageAnalysisTotals
    var needsUserReview: Bool
    var clarifyingQuestion: String?
    var usage: AIUsageMetadata?
}
