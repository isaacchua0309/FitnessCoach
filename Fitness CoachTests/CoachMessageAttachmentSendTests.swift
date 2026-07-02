//
//  CoachMessageAttachmentSendTests.swift
//  Fitness CoachTests
//
//  Forma — Coach send flow with optional image attachments.
//

import UIKit
import XCTest
@testable import Fitness_Coach

@MainActor
final class CoachMessageAttachmentSendTests: XCTestCase {

    func testSendImageOnlyAppendsUserMessageWithAttachment() async throws {
        let container = try AppContainer(inMemory: true)
        try container.userProfileService.createProfile(ProfileTestFixtures.sampleDraft)

        let imageData = Self.makeTestJPEGData()
        let model = makeModel(container: container, aiService: PhotoCapturingAIService())

        await model.importAttachment(from: .success(imageData))
        await model.sendCurrentMessage()

        let userMessage = model.messages.last(where: { $0.role == .user })
        XCTAssertEqual(userMessage?.text, CoachMealPhotoPipeline.userMessageLabel)
        XCTAssertTrue(userMessage?.hasAttachedImage == true)
        XCTAssertEqual(model.inputAttachmentState, .none)
        XCTAssertTrue(model.inputText.isEmpty)
    }

    func testSendTextAndImageAppendsBothToUserMessage() async throws {
        let container = try AppContainer(inMemory: true)
        try container.userProfileService.createProfile(ProfileTestFixtures.sampleDraft)

        let imageData = Self.makeTestJPEGData()
        let model = makeModel(container: container, aiService: PhotoCapturingAIService())

        model.inputText = "Lunch"
        await model.importAttachment(from: .success(imageData))
        await model.sendCurrentMessage()

        let userMessage = model.messages.last(where: { $0.role == .user })
        XCTAssertEqual(userMessage?.text, "Lunch")
        XCTAssertTrue(userMessage?.hasAttachedImage == true)
    }

    func testSendFailurePreservesSentMessageWithAttachment() async throws {
        let container = try AppContainer(inMemory: true)
        try container.userProfileService.createProfile(ProfileTestFixtures.sampleDraft)

        let aiService = PhotoCapturingAIService()
        aiService.estimateFoodError = AIServiceError.backendUnavailable
        let model = makeModel(container: container, aiService: aiService)
        let imageData = Self.makeTestJPEGData()

        await model.importAttachment(from: .success(imageData))
        await model.sendCurrentMessage()

        let userMessages = model.messages.filter { $0.role == .user }
        XCTAssertEqual(userMessages.count, 1)
        XCTAssertTrue(userMessages[0].hasAttachedImage)
        XCTAssertEqual(model.messages.last?.role, .assistant)
    }

    func testChatMessageHasAttachedImageRequiresNonEmptyBytes() {
        let message = ChatMessage(
            id: UUID(),
            role: .user,
            text: "Meal photo",
            createdAt: Date(),
            relatedDailyLogId: nil,
            relatedEntryId: nil,
            attachedImageJPEGData: Data()
        )

        XCTAssertFalse(message.hasAttachedImage)
    }

    private func makeModel(container: AppContainer, aiService: PhotoCapturingAIService) -> CoachModel {
        CoachModel(
            actionCenter: container.actionCenter,
            dailyLogReader: container.dailyLogService,
            healthActivityQuery: container.healthActivityQueryService,
            aiService: aiService,
            userProfileReader: container.userProfileService,
            aiCommandParsingEnabled: true
        )
    }

    private static func makeTestJPEGData() -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 12, height: 12))
        let image = renderer.image { context in
            UIColor.orange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 12, height: 12))
        }
        return image.jpegData(compressionQuality: 0.85)!
    }
}

private final class PhotoCapturingAIService: AIServiceProtocol, @unchecked Sendable {
    var estimateFoodCallCount = 0
    var estimateFoodError: Error?

    func classifyCoachIntent(
        _ text: String,
        context: AIContext,
        config: CoachModelConfig
    ) async throws -> CoachIntentResult {
        CoachMealPhotoPipeline.photoAnalysisIntentResult
    }

    func estimateFood(
        prompt: String,
        context: AIContext,
        imageJPEGData: Data?
    ) async throws -> AIFoodEstimateResponse {
        estimateFoodCallCount += 1
        if let estimateFoodError { throw estimateFoodError }

        let draft = FoodDraft(
            mealType: .lunch,
            name: "Photo meal",
            quantity: 1,
            unit: "serving",
            calories: 420,
            protein: 28,
            carbs: 35,
            fat: 14,
            fiber: nil,
            sodium: nil,
            source: .aiPhotoEstimate,
            confidence: .medium,
            imageUrl: nil,
            notes: nil
        )
        return AIFoodEstimateResponse(
            foodDrafts: [draft],
            confidence: .medium,
            requiresConfirmation: true,
            assistantMessage: "Estimated from your photo — confirm before logging."
        )
    }

    func generateMealAdvice(
        prompt: String,
        context: AIContext,
        intentResult: CoachIntentResult?,
        tier: CoachModelTier
    ) async throws -> AICoachResponse {
        AICoachResponse(message: "Stub", confidence: .medium)
    }

    func parseWorkout(prompt: String, context: AIContext) async throws -> AIWorkoutParseResponse {
        throw AIServiceError.backendUnavailable
    }

    func parseEditOrDelete(prompt: String, context: AIContext) async throws -> AIParsedCommand {
        throw AIServiceError.backendUnavailable
    }

    func parseMultiAction(prompt: String, context: AIContext) async throws -> AIParsedCommand {
        throw AIServiceError.backendUnavailable
    }

    func generateDailyReview(context: AIContext) async throws -> AICoachResponse {
        AICoachResponse(message: "Stub", confidence: .medium)
    }

    func generateDailyReviewText(input: DailyReviewAIInput, context: AIContext) async throws -> AICoachResponse {
        AICoachResponse(message: "Stub", confidence: .medium)
    }

    func parseCommand(_ text: String, context: AIContext) async throws -> AIParsedCommand {
        throw AIServiceError.backendUnavailable
    }
}
