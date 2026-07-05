//
//  CoachModelCharacterizationTestSupport.swift
//  Fitness CoachTests
//
//  Shared fakes and helpers for CoachModel decomposition characterization tests.
//

import UIKit
import XCTest
@testable import Fitness_Coach

@MainActor
enum CoachModelCharacterizationTestSupport {

    // MARK: - Transcript

    final class CapturingCoachChatTranscriptStore: CoachChatTranscriptStore {
        private var messages: [ChatMessage] = []
        private(set) var saveCount = 0

        func loadMessages() -> [ChatMessage] {
            messages
        }

        func saveMessages(_ messages: [ChatMessage]) {
            saveCount += 1
            self.messages = messages
        }

        var persistedMessages: [ChatMessage] {
            messages
        }
    }

    // MARK: - AIService stubs

    /// AI must not be called — local guard handles greetings, water, weight, catalog food.
    final class UnreachableAIService: AIServiceProtocol, @unchecked Sendable {
        private(set) var classifyCallCount = 0
        private(set) var estimateFoodCallCount = 0

        func classifyCoachIntent(
            _ text: String,
            context: CoachContextPacketV2,
            config: CoachModelConfig
        ) async throws -> CoachIntentResult {
            classifyCallCount += 1
            throw AIServiceError.backendUnavailable
        }

        func estimateFood(
            prompt: String,
            context: CoachContextPacketV2,
            imageJPEGData: Data?
        ) async throws -> AIFoodEstimateResponse {
            estimateFoodCallCount += 1
            throw AIServiceError.backendUnavailable
        }

        func analyzeMealImage(request: AIMealImageAnalysisRequest) async throws -> AIMealImageAnalysisResponse {
            throw AIServiceError.backendUnavailable
        }

        func generateMealAdvice(
            prompt: String,
            context: CoachContextPacketV2,
            intentResult: CoachIntentResult?,
            tier: CoachModelTier
        ) async throws -> AICoachResponse {
            throw AIServiceError.backendUnavailable
        }

        func generateNutritionEstimate(
            prompt: String,
            context: CoachContextPacketV2,
            intentResult: CoachIntentResult?,
            tier: CoachModelTier
        ) async throws -> NutritionEstimateResponse {
            throw AIServiceError.backendUnavailable
        }

        func generateNutritionComparison(
            prompt: String,
            context: CoachContextPacketV2,
            intentResult: CoachIntentResult?,
            tier: CoachModelTier
        ) async throws -> NutritionComparisonResponse {
            throw AIServiceError.backendUnavailable
        }

        func parseWorkout(prompt: String, context: CoachContextPacketV2) async throws -> AIWorkoutParseResponse {
            throw AIServiceError.backendUnavailable
        }

        func parseEditOrDelete(prompt: String, context: CoachContextPacketV2) async throws -> AIParsedCommand {
            throw AIServiceError.backendUnavailable
        }

        func parseMultiAction(prompt: String, context: CoachContextPacketV2) async throws -> AIParsedCommand {
            throw AIServiceError.backendUnavailable
        }

        func generateDailyReview(context: CoachContextPacketV2) async throws -> AICoachResponse {
            throw AIServiceError.backendUnavailable
        }

        func generateDailyReviewText(
            input: DailyReviewAIInput,
            context: CoachContextPacketV2
        ) async throws -> AICoachResponse {
            throw AIServiceError.backendUnavailable
        }

        func parseCommand(_ text: String, context: CoachContextPacketV2) async throws -> AIParsedCommand {
            throw AIServiceError.backendUnavailable
        }
    }

  final class FoodEstimateAIService: AIServiceProtocol, @unchecked Sendable {
        var estimateResponse: AIFoodEstimateResponse
        private(set) var classifyCallCount = 0
        private(set) var estimateFoodCallCount = 0

        init(estimateResponse: AIFoodEstimateResponse = FoodEstimateAIService.defaultResponse) {
            self.estimateResponse = estimateResponse
        }

        static var defaultResponse: AIFoodEstimateResponse {
            AIFoodEstimateResponse(
                foodLogDrafts: [
                    FoodLogDraft(
                        displayName: "Chicken rice bowl",
                        components: [
                            FoodComponent(
                                name: "Chicken rice bowl",
                                calories: 620,
                                protein: 42,
                                carbs: 55,
                                fat: 18,
                                confidence: .medium,
                                sourceText: "log chicken rice bowl"
                            )
                        ],
                        confidence: .medium,
                        source: .aiTextEstimate
                    )
                ],
                confidence: .medium,
                requiresConfirmation: true,
                assistantMessage: "Confirm before logging."
            )
        }

        func classifyCoachIntent(
            _ text: String,
            context: CoachContextPacketV2,
            config: CoachModelConfig
        ) async throws -> CoachIntentResult {
            classifyCallCount += 1
            return CoachIntentResult(
                intent: .logFood,
                confidence: 0.92,
                domain: .nutrition,
                requiresAppMutation: true,
                requiresUserContext: true,
                canAnswerWithCheapModel: true,
                requiresEscalation: false,
                action: nil
            )
        }

        func estimateFood(
            prompt: String,
            context: CoachContextPacketV2,
            imageJPEGData: Data?
        ) async throws -> AIFoodEstimateResponse {
            estimateFoodCallCount += 1
            return estimateResponse
        }

        func analyzeMealImage(request: AIMealImageAnalysisRequest) async throws -> AIMealImageAnalysisResponse {
            throw AIServiceError.backendUnavailable
        }

        func generateMealAdvice(
            prompt: String,
            context: CoachContextPacketV2,
            intentResult: CoachIntentResult?,
            tier: CoachModelTier
        ) async throws -> AICoachResponse {
            throw AIServiceError.backendUnavailable
        }

        func generateNutritionEstimate(
            prompt: String,
            context: CoachContextPacketV2,
            intentResult: CoachIntentResult?,
            tier: CoachModelTier
        ) async throws -> NutritionEstimateResponse {
            throw AIServiceError.backendUnavailable
        }

        func generateNutritionComparison(
            prompt: String,
            context: CoachContextPacketV2,
            intentResult: CoachIntentResult?,
            tier: CoachModelTier
        ) async throws -> NutritionComparisonResponse {
            throw AIServiceError.backendUnavailable
        }

        func parseWorkout(prompt: String, context: CoachContextPacketV2) async throws -> AIWorkoutParseResponse {
            throw AIServiceError.backendUnavailable
        }

        func parseEditOrDelete(prompt: String, context: CoachContextPacketV2) async throws -> AIParsedCommand {
            throw AIServiceError.backendUnavailable
        }

        func parseMultiAction(prompt: String, context: CoachContextPacketV2) async throws -> AIParsedCommand {
            throw AIServiceError.backendUnavailable
        }

        func generateDailyReview(context: CoachContextPacketV2) async throws -> AICoachResponse {
            throw AIServiceError.backendUnavailable
        }

        func generateDailyReviewText(
            input: DailyReviewAIInput,
            context: CoachContextPacketV2
        ) async throws -> AICoachResponse {
            throw AIServiceError.backendUnavailable
        }

        func parseCommand(_ text: String, context: CoachContextPacketV2) async throws -> AIParsedCommand {
            throw AIServiceError.backendUnavailable
        }
    }

    final class FailingEstimateAIService: AIServiceProtocol, @unchecked Sendable {
        private(set) var classifyCallCount = 0
        private(set) var estimateFoodCallCount = 0

        func classifyCoachIntent(
            _ text: String,
            context: CoachContextPacketV2,
            config: CoachModelConfig
        ) async throws -> CoachIntentResult {
            classifyCallCount += 1
            return CoachIntentResult(
                intent: .logFood,
                confidence: 0.92,
                domain: .nutrition,
                requiresAppMutation: true,
                requiresUserContext: true,
                canAnswerWithCheapModel: true,
                requiresEscalation: false,
                action: nil
            )
        }

        func estimateFood(
            prompt: String,
            context: CoachContextPacketV2,
            imageJPEGData: Data?
        ) async throws -> AIFoodEstimateResponse {
            estimateFoodCallCount += 1
            throw AIServiceError.backendUnavailable
        }

        func analyzeMealImage(request: AIMealImageAnalysisRequest) async throws -> AIMealImageAnalysisResponse {
            throw AIServiceError.backendUnavailable
        }

        func generateMealAdvice(
            prompt: String,
            context: CoachContextPacketV2,
            intentResult: CoachIntentResult?,
            tier: CoachModelTier
        ) async throws -> AICoachResponse {
            throw AIServiceError.backendUnavailable
        }

        func generateNutritionEstimate(
            prompt: String,
            context: CoachContextPacketV2,
            intentResult: CoachIntentResult?,
            tier: CoachModelTier
        ) async throws -> NutritionEstimateResponse {
            throw AIServiceError.backendUnavailable
        }

        func generateNutritionComparison(
            prompt: String,
            context: CoachContextPacketV2,
            intentResult: CoachIntentResult?,
            tier: CoachModelTier
        ) async throws -> NutritionComparisonResponse {
            throw AIServiceError.backendUnavailable
        }

        func parseWorkout(prompt: String, context: CoachContextPacketV2) async throws -> AIWorkoutParseResponse {
            throw AIServiceError.backendUnavailable
        }

        func parseEditOrDelete(prompt: String, context: CoachContextPacketV2) async throws -> AIParsedCommand {
            throw AIServiceError.backendUnavailable
        }

        func parseMultiAction(prompt: String, context: CoachContextPacketV2) async throws -> AIParsedCommand {
            throw AIServiceError.backendUnavailable
        }

        func generateDailyReview(context: CoachContextPacketV2) async throws -> AICoachResponse {
            throw AIServiceError.backendUnavailable
        }

        func generateDailyReviewText(
            input: DailyReviewAIInput,
            context: CoachContextPacketV2
        ) async throws -> AICoachResponse {
            throw AIServiceError.backendUnavailable
        }

        func parseCommand(_ text: String, context: CoachContextPacketV2) async throws -> AIParsedCommand {
            throw AIServiceError.backendUnavailable
        }
    }

    final class CharacterizationPhotoAIService: AIServiceProtocol, @unchecked Sendable {
        var analyzeMealImageCallCount = 0
        var injectedAnalyzeError: Error?
        var clarifyingQuestion: String?
        private var callIndex = 0

        func classifyCoachIntent(
            _ text: String,
            context: CoachContextPacketV2,
            config: CoachModelConfig
        ) async throws -> CoachIntentResult {
            CoachMealPhotoPipeline.photoAnalysisIntentResult
        }

        func analyzeMealImage(request: AIMealImageAnalysisRequest) async throws -> AIMealImageAnalysisResponse {
            analyzeMealImageCallCount += 1
            callIndex += 1
            if let injectedAnalyzeError, callIndex == 1 {
                throw injectedAnalyzeError
            }

            let confidence: AIConfidence = clarifyingQuestion != nil && callIndex == 1 ? .low : .medium
            return CoachImageWorkflowTestSupport.validMealImageAnalysisResponse(
                summary: "Photo meal",
                itemName: "Photo meal",
                confidence: confidence
            ).withClarifyingQuestion(
                clarifyingQuestion != nil && callIndex == 1 ? clarifyingQuestion : nil
            )
        }

        func estimateFood(
            prompt: String,
            context: CoachContextPacketV2,
            imageJPEGData: Data?
        ) async throws -> AIFoodEstimateResponse {
            throw AIServiceError.backendUnavailable
        }

        func generateMealAdvice(
            prompt: String,
            context: CoachContextPacketV2,
            intentResult: CoachIntentResult?,
            tier: CoachModelTier
        ) async throws -> AICoachResponse {
            AICoachResponse(message: "Stub", confidence: .medium)
        }

        func parseWorkout(prompt: String, context: CoachContextPacketV2) async throws -> AIWorkoutParseResponse {
            throw AIServiceError.backendUnavailable
        }

        func parseEditOrDelete(prompt: String, context: CoachContextPacketV2) async throws -> AIParsedCommand {
            throw AIServiceError.backendUnavailable
        }

        func parseMultiAction(prompt: String, context: CoachContextPacketV2) async throws -> AIParsedCommand {
            throw AIServiceError.backendUnavailable
        }

        func generateDailyReview(context: CoachContextPacketV2) async throws -> AICoachResponse {
            AICoachResponse(message: "Stub", confidence: .medium)
        }

        func generateDailyReviewText(
            input: DailyReviewAIInput,
            context: CoachContextPacketV2
        ) async throws -> AICoachResponse {
            AICoachResponse(message: "Stub", confidence: .medium)
        }

        func parseCommand(_ text: String, context: CoachContextPacketV2) async throws -> AIParsedCommand {
            throw AIServiceError.backendUnavailable
        }
    }

    // MARK: - Helpers

    static func waitForTimelineEvent(
        in store: FakeCoachTimelineStore,
        matching predicate: @escaping (CoachTimelineEvent) -> Bool,
        timeout: TimeInterval = 1.0
    ) async throws -> CoachTimelineEvent {
        let satisfied = await AsyncTestSupport.waitUntil(
            maxYields: Int(timeout * 100),
            { store.events.contains(where: predicate) }
        )
        if !satisfied {
            throw NSError(domain: "CoachModelCharacterizationTestSupport", code: 1)
        }
        return try XCTUnwrap(store.events.first(where: predicate))
    }

    @MainActor
    static func stageAndSendPhoto(
        on model: CoachModel,
        aiService: CharacterizationPhotoAIService,
        jpeg: Data? = nil
    ) async throws -> UUID {
        let imageData = jpeg ?? CoachImageWorkflowTestSupport.makeTestJPEG()
        let staged = await CoachImageWorkflowTestSupport.stageTestMealPhoto(
            on: model,
            jpeg: imageData,
            source: .library
        )
        XCTAssertTrue(staged)
        await model.sendCurrentMessage()
        return try XCTUnwrap(model.messages.first { $0.role == .user }?.id)
    }
}

private extension AIMealImageAnalysisResponse {
    func withClarifyingQuestion(_ question: String?) -> AIMealImageAnalysisResponse {
        AIMealImageAnalysisResponse(
            summary: summary,
            items: items,
            total: total,
            needsUserReview: needsUserReview,
            clarifyingQuestion: question
        )
    }
}
