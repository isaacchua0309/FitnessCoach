//
//  CoachMealPhotoAnalysisTests.swift
//  Fitness CoachTests
//
//  Forma — Meal photo pipeline and photoFoodAnalysis routing.
//

import UIKit
import XCTest
@testable import Fitness_Coach

@MainActor
final class CoachMealPhotoAnalysisTests: XCTestCase {

    func testPrepareJPEGRejectsEmptyData() {
        XCTAssertEqual(
            CoachMealPhotoPipeline.prepareJPEG(from: Data()),
            .failure(.noImage)
        )
    }

    func testPrepareJPEGAcceptsRenderedImage() {
        let raw = Self.makeTestJPEGData()
        guard case .success(let prepared) = CoachMealPhotoPipeline.prepareJPEG(from: raw) else {
            return XCTFail("Expected valid JPEG payload")
        }
        XCTAssertTrue(CoachMealPhotoPipeline.hasImagePayload(prepared))
        XCTAssertGreaterThan(prepared.count, 0)
    }

    func testHasImagePayloadRequiresNonEmptyBytes() {
        XCTAssertFalse(CoachMealPhotoPipeline.hasImagePayload(nil))
        XCTAssertFalse(CoachMealPhotoPipeline.hasImagePayload(Data()))
        XCTAssertTrue(CoachMealPhotoPipeline.hasImagePayload(Data([0xFF, 0xD8, 0xFF])))
    }

    func testPhotoSelectionStagesAttachmentWithoutSending() async throws {
        let container = try AppContainer(inMemory: true)
        let model = makeModel(container: container)

        model.handleMealPhotoSelection(.success(Self.makeTestJPEGData()), source: .library)

        XCTAssertNotNil(model.inputState.attachment)
        XCTAssertEqual(model.inputState.attachment?.source, .library)
        XCTAssertTrue(model.messages.isEmpty)
        XCTAssertFalse(model.isSending)
    }

    func testRemovingStagedPhotoAllowsAnotherSelection() async throws {
        let container = try AppContainer(inMemory: true)
        let model = makeModel(container: container)
        let first = Self.makeTestJPEGData()

        model.handleMealPhotoSelection(.success(first), source: .library)
        XCTAssertNotNil(model.inputState.attachment)

        model.removeStagedMealPhoto()
        XCTAssertNil(model.inputState.attachment)

        model.handleMealPhotoSelection(.success(first), source: .camera)
        XCTAssertEqual(model.inputState.attachment?.source, .camera)
    }

    func testSecondPickWithoutRemoveSetsComposerError() async throws {
        let container = try AppContainer(inMemory: true)
        let model = makeModel(container: container)
        let first = Self.makeTestJPEGData()

        model.handleMealPhotoSelection(.success(first), source: .library)
        let firstID = try XCTUnwrap(model.inputState.attachment?.id)

        XCTAssertFalse(model.requestPhotoPick())
        XCTAssertEqual(model.inputState.error, .attachmentAlreadyPresent)
        XCTAssertEqual(model.inputState.attachment?.id, firstID)
    }

    func testPhotoAnalysisSendsImagePayloadToAIService() async throws {
        let container = try AppContainer(inMemory: true)
        try container.userProfileService.createProfile(ProfileTestFixtures.sampleDraft)

        let imageData = Self.makeTestJPEGData()
        let aiService = PhotoCapturingAIService()
        let model = CoachModel(
            actionCenter: container.actionCenter,
            dailyLogReader: container.dailyLogService,
            healthActivityQuery: container.healthActivityQueryService,
            aiService: aiService,
            userProfileReader: container.userProfileService,
            aiCommandParsingEnabled: true
        )

        model.handleMealPhotoSelection(.success(imageData), source: .library)
        await model.sendCurrentMessage()

        XCTAssertEqual(aiService.estimateFoodCallCount, 1)
        XCTAssertTrue(CoachMealPhotoPipeline.hasImagePayload(aiService.lastImageJPEGData))
        if case .success(let expectedPayload) = CoachMealPhotoPipeline.prepareJPEG(from: imageData) {
            XCTAssertEqual(aiService.lastImageJPEGData, expectedPayload)
        } else {
            XCTFail("Expected prepared JPEG payload")
        }
        XCTAssertNotNil(model.pendingConfirmation)
        XCTAssertEqual(model.messages.first?.mealPhotoJPEG, aiService.lastImageJPEGData)
        XCTAssertNil(model.stagedMealPhotoJPEG)
        XCTAssertEqual(model.messages.last?.role, .assistant)
    }

    func testSendImageOnlyCreatesPhotoBubbleWithoutPlaceholderText() async throws {
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

        model.handleMealPhotoSelection(.success(Self.makeTestJPEGData()), source: .library)
        await model.sendCurrentMessage()

        let userMessage = try XCTUnwrap(model.messages.first { $0.role == .user })
        XCTAssertNotNil(userMessage.mealPhotoJPEG)
        XCTAssertTrue(userMessage.text.isEmpty)
        XCTAssertNotEqual(userMessage.text, CoachMealPhotoPipeline.userMessageLabel)
    }

    func testSendTextAndImageUsesCaptionAsPrompt() async throws {
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

        model.inputText = "Lunch bowl"
        model.handleMealPhotoSelection(.success(Self.makeTestJPEGData()), source: .library)
        await model.sendCurrentMessage()

        XCTAssertEqual(aiService.lastPrompt, "Lunch bowl")
        let userMessage = try XCTUnwrap(model.messages.first { $0.role == .user })
        XCTAssertEqual(userMessage.text, "Lunch bowl")
        XCTAssertNotNil(userMessage.mealPhotoJPEG)
    }

    func testMissingImageSurfacesNonShamingError() async throws {
        let container = try AppContainer(inMemory: true)
        try container.userProfileService.createProfile(ProfileTestFixtures.sampleDraft)

        let model = makeModel(container: container)

        model.handleMealPhotoSelection(.failure(.noImage), source: .library)

        XCTAssertEqual(model.messages.last?.text, CoachResponseBuilder.mealPhotoError(.noImage))
        XCTAssertNil(model.pendingConfirmation)
        XCTAssertNil(model.stagedMealPhotoJPEG)
    }

    func testUserCancellationDoesNotAppendMessages() async throws {
        let container = try AppContainer(inMemory: true)
        let model = makeModel(container: container)

        model.handleMealPhotoSelection(.failure(.userCancelled), source: .library)

        XCTAssertTrue(model.messages.isEmpty)
        XCTAssertNil(model.stagedMealPhotoJPEG)
    }

    func testAIFailureSurfacesAnalysisErrorAndRetry() async throws {
        let container = try AppContainer(inMemory: true)
        try container.userProfileService.createProfile(ProfileTestFixtures.sampleDraft)

        let aiService = PhotoCapturingAIService()
        aiService.estimateFoodError = AIServiceError.backendUnavailable
        let model = CoachModel(
            actionCenter: container.actionCenter,
            dailyLogReader: container.dailyLogService,
            healthActivityQuery: container.healthActivityQueryService,
            aiService: aiService,
            userProfileReader: container.userProfileService,
            aiCommandParsingEnabled: true
        )

        model.handleMealPhotoSelection(.success(Self.makeTestJPEGData()), source: .library)
        await model.sendCurrentMessage()

        XCTAssertNotNil(model.messages.first { $0.role == .user }?.mealPhotoJPEG)
        XCTAssertTrue(model.messages.contains { $0.mealPhotoAnalysisFailure != nil })
        XCTAssertTrue(model.messages.last?.text.contains("couldn't analyze") == true)
        XCTAssertNil(model.pendingConfirmation)

        aiService.estimateFoodError = nil
        let userMessageID = try XCTUnwrap(model.messages.first { $0.role == .user }?.id)
        await model.retryMealPhotoAnalysis(for: userMessageID)

        XCTAssertEqual(aiService.estimateFoodCallCount, 2)
        XCTAssertNotNil(model.pendingConfirmation)
        XCTAssertFalse(model.messages.contains { $0.mealPhotoAnalysisFailure != nil })
    }

    func testTodayScanFoodVisibleWhenPipelineReady() {
        XCTAssertTrue(TodayPhotoScanAvailability.isPipelineReady)
        XCTAssertTrue(TodayQuickActionPolicy.isVisible(.scanFood))
        XCTAssertTrue(
            TodayQuickActionPolicy.menuItems().contains { $0.kind == .scanFood && $0.isEnabled }
        )
    }

    func testLegacyHandlePhotoSelectedReportsMissingImage() async throws {
        let container = try AppContainer(inMemory: true)
        let model = makeModel(container: container)

        model.handlePhotoSelected()

        XCTAssertEqual(model.messages.last?.text, CoachResponseBuilder.mealPhotoError(.noImage))
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
    var lastPrompt: String?
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
        lastPrompt = prompt
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
