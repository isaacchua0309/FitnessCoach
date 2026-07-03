//
//  CoachImageWorkflowTestSupport.swift
//  Fitness CoachTests
//
//  Shared harness for Coach meal-photo workflow end-to-end tests.
//

import UIKit
import XCTest
@testable import Fitness_Coach

@MainActor
enum CoachImageWorkflowTestSupport {

    static func makeTestJPEG(
        size: CGSize = CGSize(width: 24, height: 24),
        color: UIColor = .orange
    ) -> Data {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        return image.jpegData(compressionQuality: 0.85)!
    }

    static func makeCoach(
        aiService: AIServiceProtocol,
        container: AppContainer? = nil
    ) throws -> (CoachModel, AppContainer) {
        let resolvedContainer: AppContainer
        if let container {
            resolvedContainer = container
        } else {
            resolvedContainer = try AppContainer(inMemory: true)
        }
        try resolvedContainer.userProfileService.createProfile(ProfileTestFixtures.sampleDraft)
        let model = CoachModel(
            actionCenter: resolvedContainer.actionCenter,
            dailyLogReader: resolvedContainer.dailyLogService,
            healthActivityQuery: resolvedContainer.healthActivityQueryService,
            aiService: aiService,
            userProfileReader: resolvedContainer.userProfileService,
            aiCommandParsingEnabled: true
        )
        return (model, resolvedContainer)
    }

    static func validMealImageAnalysisResponse(
        summary: String = "Photo meal",
        itemName: String = "Photo meal",
        confidence: AIConfidence = .medium
    ) -> AIMealImageAnalysisResponse {
        AIMealImageAnalysisResponse(
            summary: summary,
            items: [
                AIMealImageAnalysisItem(
                    name: itemName,
                    quantity: "1 serving",
                    calories: 420,
                    protein: 28,
                    carbs: 35,
                    fat: 14,
                    confidence: confidence,
                    assumptions: ["Estimated from your photo — confirm before logging."]
                )
            ],
            total: AIMealImageAnalysisTotals(
                calories: 420,
                protein: 28,
                carbs: 35,
                fat: 14
            ),
            needsUserReview: true,
            clarifyingQuestion: confidence == .low ? "Was this rice or barley?" : nil
        )
    }
}

// MARK: - Capturing AI service

final class WorkflowCapturingPhotoAIService: AIServiceProtocol, @unchecked Sendable {
    var analyzeMealImageCallCount = 0
    var receivedImagePayloads: [Data] = []
    var receivedPrompts: [String?] = []
    var receivedClarifications: [String?] = []
    var injectedError: Error?

    func classifyCoachIntent(
        _ text: String,
        context: CoachContextPacketV2,
        config: CoachModelConfig
    ) async throws -> CoachIntentResult {
        CoachMealPhotoPipeline.photoAnalysisIntentResult
    }

    func analyzeMealImage(request: AIMealImageAnalysisRequest) async throws -> AIMealImageAnalysisResponse {
        analyzeMealImageCallCount += 1
        if let data = Data(base64Encoded: request.image.base64) {
            receivedImagePayloads.append(data)
        }
        receivedPrompts.append(request.message)
        receivedClarifications.append(request.clarification)
        if let injectedError { throw injectedError }

        return CoachImageWorkflowTestSupport.validMealImageAnalysisResponse()
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

    func generateDailyReviewText(input: DailyReviewAIInput, context: CoachContextPacketV2) async throws -> AICoachResponse {
        AICoachResponse(message: "Stub", confidence: .medium)
    }

    func parseCommand(_ text: String, context: CoachContextPacketV2) async throws -> AIParsedCommand {
        throw AIServiceError.backendUnavailable
    }
}

// MARK: - Holdable AI service (pending-state tests)

final class HoldablePhotoAIService: AIServiceProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var waiters: [CheckedContinuation<Void, Never>] = []

    var analyzeMealImageCallCount = 0
    var shouldHold = true

    func releaseAll() {
        lock.lock()
        let pending = waiters
        waiters = []
        lock.unlock()
        pending.forEach { $0.resume() }
    }

    func classifyCoachIntent(
        _ text: String,
        context: CoachContextPacketV2,
        config: CoachModelConfig
    ) async throws -> CoachIntentResult {
        CoachMealPhotoPipeline.photoAnalysisIntentResult
    }

    func analyzeMealImage(request: AIMealImageAnalysisRequest) async throws -> AIMealImageAnalysisResponse {
        analyzeMealImageCallCount += 1
        if shouldHold {
            await withCheckedContinuation { continuation in
                lock.lock()
                waiters.append(continuation)
                lock.unlock()
            }
        }
        return CoachImageWorkflowTestSupport.validMealImageAnalysisResponse()
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

    func generateDailyReviewText(input: DailyReviewAIInput, context: CoachContextPacketV2) async throws -> AICoachResponse {
        AICoachResponse(message: "Stub", confidence: .medium)
    }

    func parseCommand(_ text: String, context: CoachContextPacketV2) async throws -> AIParsedCommand {
        throw AIServiceError.backendUnavailable
    }
}

// MARK: - Retry-improving AI service

final class RetryImprovingWorkflowAIService: AIServiceProtocol, @unchecked Sendable {
    var analyzeMealImageCallCount = 0

    func classifyCoachIntent(
        _ text: String,
        context: CoachContextPacketV2,
        config: CoachModelConfig
    ) async throws -> CoachIntentResult {
        CoachMealPhotoPipeline.photoAnalysisIntentResult
    }

    func analyzeMealImage(request: AIMealImageAnalysisRequest) async throws -> AIMealImageAnalysisResponse {
        analyzeMealImageCallCount += 1
        let confidence: AIConfidence = analyzeMealImageCallCount == 1 ? .low : .medium
        return CoachImageWorkflowTestSupport.validMealImageAnalysisResponse(
            summary: "Grain bowl",
            itemName: "Grain bowl",
            confidence: confidence
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

    func generateDailyReviewText(input: DailyReviewAIInput, context: CoachContextPacketV2) async throws -> AICoachResponse {
        AICoachResponse(message: "Stub", confidence: .medium)
    }

    func parseCommand(_ text: String, context: CoachContextPacketV2) async throws -> AIParsedCommand {
        throw AIServiceError.backendUnavailable
    }
}
