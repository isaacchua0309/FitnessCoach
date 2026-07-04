//
//  CoachInputAttachmentStateTests.swift
//  Fitness CoachTests
//
//  Forma — Coach composer image attachment state.
//

import UIKit
import XCTest
@testable import Fitness_Coach

@MainActor
final class CoachInputAttachmentStateTests: XCTestCase {

    func testCancelImportPreservesExistingAttachment() async throws {
        let container = try AppContainer(inMemory: true)
        let model = makeModel(container: container)
        let firstImage = Self.makeTestJPEGData()
        let secondImage = Self.makeTestJPEGData()

        await model.importAttachment(from: .success(firstImage))
        guard let firstAttachment = model.inputAttachmentState.attachment else {
            return XCTFail("Expected staged attachment")
        }

        await model.importAttachment(from: .failure(.userCancelled))

        XCTAssertEqual(model.inputAttachmentState.attachment?.id, firstAttachment.id)
        XCTAssertEqual(model.inputAttachmentState.importPhase, .idle)
    }

    func testFailedImportPreservesExistingAttachment() async throws {
        let container = try AppContainer(inMemory: true)
        let model = makeModel(container: container)
        let firstImage = Self.makeTestJPEGData()

        await model.importAttachment(from: .success(firstImage))
        guard let firstAttachment = model.inputAttachmentState.attachment else {
            return XCTFail("Expected staged attachment")
        }

        await model.importAttachment(from: .failure(.noImage))

        XCTAssertEqual(model.inputAttachmentState.attachment?.id, firstAttachment.id)
        XCTAssertEqual(model.inputAttachmentState.importError, .noImage)
    }

    func testSuccessfulImportReplacesExistingAttachment() async throws {
        let container = try AppContainer(inMemory: true)
        let model = makeModel(container: container)
        let firstImage = Self.makeTestJPEGData()
        let secondImage = Self.makeTestJPEGData()

        await model.importAttachment(from: .success(firstImage), sourceLabel: "first.jpg")
        guard let firstAttachment = model.inputAttachmentState.attachment else {
            return XCTFail("Expected first attachment")
        }

        await model.importAttachment(from: .success(secondImage), sourceLabel: "second.jpg")

        XCTAssertNotEqual(model.inputAttachmentState.attachment?.id, firstAttachment.id)
        XCTAssertEqual(model.inputAttachmentState.attachment?.sourceLabel, "second.jpg")
        XCTAssertEqual(model.inputAttachmentState.importPhase, .idle)
    }

    func testRemoveClearsAttachmentButPreservesTypedMessage() async throws {
        let container = try AppContainer(inMemory: true)
        let model = makeModel(container: container)

        model.inputText = "Lunch log"
        await model.importAttachment(from: .success(Self.makeTestJPEGData()))
        XCTAssertTrue(model.inputAttachmentState.hasAttachment)

        model.removeInputAttachment()

        XCTAssertEqual(model.inputAttachmentState, .none)
        XCTAssertEqual(model.inputText, "Lunch log")
    }

    func testRemoveClearsAllAttachmentState() async throws {
        let container = try AppContainer(inMemory: true)
        let model = makeModel(container: container)

        await model.importAttachment(from: .failure(.noImage))
        model.removeInputAttachment()

        XCTAssertEqual(model.inputAttachmentState, .none)
    }

    func testCameraCaptureStagesAttachmentWithoutSending() async throws {
        let container = try AppContainer(inMemory: true)
        let model = makeModel(container: container)
        let imageData = Self.makeTestJPEGData()

        await model.importAttachment(
            from: .success(imageData),
            sourceLabel: CoachMealPhotoPipeline.cameraCaptureLabel
        )

        XCTAssertTrue(model.inputAttachmentState.hasAttachment)
        XCTAssertEqual(model.inputAttachmentState.attachment?.sourceLabel, CoachMealPhotoPipeline.cameraCaptureLabel)
        XCTAssertNotNil(model.inputAttachmentState.previewImage)
        XCTAssertTrue(model.messages.isEmpty)
    }

    func testCameraUnavailableShowsErrorWithoutClearingExistingAttachment() async throws {
        let container = try AppContainer(inMemory: true)
        let model = makeModel(container: container)
        let existingImage = Self.makeTestJPEGData()

        await model.importAttachment(from: .success(existingImage), sourceLabel: "library.jpg")
        guard let existingAttachment = model.inputAttachmentState.attachment else {
            return XCTFail("Expected existing attachment")
        }

        await model.importAttachment(from: .failure(.cameraUnavailable))

        XCTAssertEqual(model.inputAttachmentState.attachment?.id, existingAttachment.id)
        XCTAssertEqual(model.inputAttachmentState.importError, .cameraUnavailable)
    }

    func testCameraCancelPreservesExistingAttachment() async throws {
        let container = try AppContainer(inMemory: true)
        let model = makeModel(container: container)
        let existingImage = Self.makeTestJPEGData()

        await model.importAttachment(from: .success(existingImage), sourceLabel: "library.jpg")
        guard let existingAttachment = model.inputAttachmentState.attachment else {
            return XCTFail("Expected existing attachment")
        }

        await model.importAttachment(from: .failure(.userCancelled))

        XCTAssertEqual(model.inputAttachmentState.attachment?.id, existingAttachment.id)
        XCTAssertEqual(model.inputAttachmentState.importPhase, .idle)
    }

    func testSendClearsAttachmentAfterUserMessageAccepted() async throws {
        let container = try AppContainer(inMemory: true)
        try container.userProfileService.createProfile(ProfileTestFixtures.sampleDraft)

        let aiService = PhotoCapturingAIService()
        let model = CoachModel(
            actionCenter: container.actionCenter,
            dailyLogReader: container.dailyLogService,
            healthActivityQuery: container.healthActivityQueryService,
            aiService: aiService,
            userProfileReader: container.userProfileService,
            aiCommandParsingEnabled: true
        )

        await model.importAttachment(from: .success(Self.makeTestJPEGData()))
        XCTAssertTrue(model.inputAttachmentState.hasAttachment)

        await model.sendCurrentMessage()

        XCTAssertEqual(model.inputAttachmentState, .none)
        XCTAssertEqual(model.messages.last(where: { $0.role == .user })?.text, CoachMealPhotoPipeline.userMessageLabel)
        XCTAssertEqual(aiService.estimateFoodCallCount, 1)
    }

    func testSendWithTextAndAttachmentUsesProvidedMessage() async throws {
        let container = try AppContainer(inMemory: true)
        try container.userProfileService.createProfile(ProfileTestFixtures.sampleDraft)

        let model = CoachModel(
            actionCenter: container.actionCenter,
            dailyLogReader: container.dailyLogService,
            healthActivityQuery: container.healthActivityQueryService,
            aiService: PhotoCapturingAIService(),
            userProfileReader: container.userProfileService,
            aiCommandParsingEnabled: true
        )

        model.inputText = "Lunch photo"
        await model.importAttachment(from: .success(Self.makeTestJPEGData()))
        await model.sendCurrentMessage()

        XCTAssertEqual(model.messages.last(where: { $0.role == .user })?.text, "Lunch photo")
        XCTAssertEqual(model.inputAttachmentState, .none)
    }

    private func makeModel(container: AppContainer) -> CoachModel {
        CoachModel(
            actionCenter: container.actionCenter,
            dailyLogReader: container.dailyLogService,
            healthActivityQuery: container.healthActivityQueryService,
            aiService: PhotoCapturingAIService(),
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
    var lastImageJPEGData: Data?
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
        lastImageJPEGData = imageJPEGData
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
