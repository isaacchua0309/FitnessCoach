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

    func testPipelineRejectsInvalidImage() {
        let emptyImage = UIImage()
        XCTAssertEqual(CoachImagePipeline.process(image: emptyImage), .failure(.invalidInput))
    }

    func testPipelineAcceptsRenderedImage() async {
        let raw = Self.makeTestJPEGData()
        guard let image = UIImage(data: raw),
              case .success(let processed) = CoachImagePipeline.process(image: image) else {
            return XCTFail("Expected valid JPEG payload")
        }
        XCTAssertTrue(CoachMealPhotoPipeline.hasImagePayload(processed.uploadData))
        XCTAssertGreaterThan(processed.uploadData.count, 0)
    }

    func testHasImagePayloadRequiresNonEmptyBytes() {
        XCTAssertFalse(CoachMealPhotoPipeline.hasImagePayload(nil))
        XCTAssertFalse(CoachMealPhotoPipeline.hasImagePayload(Data()))
        XCTAssertTrue(CoachMealPhotoPipeline.hasImagePayload(Data([0xFF, 0xD8, 0xFF])))
    }

    func testPhotoSelectionStagesAttachmentWithoutSending() async throws {
        let container = try AppContainer(inMemory: true)
        let model = makeModel(container: container)

        XCTAssertTrue(await CoachImageWorkflowTestSupport.stageTestMealPhoto(
            on: model,
            jpeg: Self.makeTestJPEGData(),
            source: .library
        ))

        XCTAssertNotNil(model.inputState.pendingImage)
        XCTAssertEqual(model.inputState.pendingImage?.source, .library)
        XCTAssertTrue(model.messages.isEmpty)
        XCTAssertFalse(model.isSending)
    }

    func testRemovingStagedPhotoAllowsAnotherSelection() async throws {
        let container = try AppContainer(inMemory: true)
        let model = makeModel(container: container)
        let first = Self.makeTestJPEGData()

        XCTAssertTrue(await CoachImageWorkflowTestSupport.stageTestMealPhoto(on: model, jpeg: first, source: .library))
        XCTAssertNotNil(model.inputState.pendingImage)

        model.removeStagedMealPhoto()
        XCTAssertNil(model.inputState.pendingImage)

        XCTAssertTrue(await CoachImageWorkflowTestSupport.stageTestMealPhoto(on: model, jpeg: first, source: .camera))
        XCTAssertEqual(model.inputState.pendingImage?.source, .camera)
    }

    func testSecondPickWithoutRemoveReplacesPendingImageAfterSuccess() async throws {
        let container = try AppContainer(inMemory: true)
        let model = makeModel(container: container)
        let first = Self.makeTestJPEGData()
        let second = Self.makeTestJPEGData(color: .systemBlue)

        XCTAssertTrue(await CoachImageWorkflowTestSupport.stageTestMealPhoto(on: model, jpeg: first, source: .library))
        let firstID = try XCTUnwrap(model.inputState.pendingImage?.id)

        XCTAssertTrue(model.requestPhotoPick())
        XCTAssertTrue(await CoachImageWorkflowTestSupport.stageTestMealPhoto(on: model, jpeg: second, source: .camera))

        XCTAssertNotEqual(model.inputState.pendingImage?.id, firstID)
        XCTAssertEqual(model.inputState.pendingImage?.source, .camera)
        XCTAssertNil(model.inputState.imageError)
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

        XCTAssertTrue(await CoachImageWorkflowTestSupport.stageTestMealPhoto(on: model, jpeg: imageData, source: .library))
        await model.sendCurrentMessage()

        XCTAssertEqual(aiService.analyzeMealImageCallCount, 1)
        XCTAssertTrue(CoachMealPhotoPipeline.hasImagePayload(aiService.lastImageJPEGData))
        if let expectedPayload = CoachImageWorkflowTestSupport.processedUploadData(from: imageData) {
            XCTAssertEqual(aiService.lastImageJPEGData, expectedPayload)
        } else {
            XCTFail("Expected prepared JPEG payload")
        }
        XCTAssertNotNil(model.pendingConfirmation)
        XCTAssertEqual(model.messages.first?.mealPhotoJPEG, aiService.lastImageJPEGData)
        XCTAssertNotNil(model.messages.first?.imageAttachment?.thumbnailJPEG)
        XCTAssertEqual(model.messages.last?.photoAnalysisLink?.isFailure, false)
        XCTAssertNil(model.inputState.pendingImage)
        XCTAssertEqual(model.messages.last?.role, .assistant)
        XCTAssertTrue(model.messages.last?.text.contains("From your meal photo") == true)
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

        XCTAssertTrue(await CoachImageWorkflowTestSupport.stageTestMealPhoto(
            on: model,
            jpeg: Self.makeTestJPEGData(),
            source: .library
        ))
        await model.sendCurrentMessage()

        let userMessage = try XCTUnwrap(model.messages.first { $0.role == .user })
        XCTAssertNotNil(userMessage.imageAttachment)
        XCTAssertNotNil(userMessage.mealPhotoJPEG)
        XCTAssertFalse(userMessage.imageAttachment?.thumbnailJPEG.isEmpty == true)
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
        XCTAssertTrue(await CoachImageWorkflowTestSupport.stageTestMealPhoto(
            on: model,
            jpeg: Self.makeTestJPEGData(),
            source: .library
        ))
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

        model.appendMealPhotoSelectionFailure(.noImage)

        XCTAssertEqual(model.messages.last?.text, CoachResponseBuilder.mealPhotoError(.noImage))
        XCTAssertNil(model.pendingConfirmation)
        XCTAssertNil(model.inputState.pendingImage)
    }

    func testUserCancellationDoesNotAppendMessages() async throws {
        let container = try AppContainer(inMemory: true)
        let model = makeModel(container: container)

        let flow = CoachImagePickFlowController()
        flow.setStateForTests(.pickerPresented(.camera))
        await flow.handleCameraResult(.failure(.userCancelled), model: model)

        XCTAssertTrue(model.messages.isEmpty)
        XCTAssertNil(model.inputState.pendingImage)
    }

    func testAIFailureSurfacesAnalysisErrorAndRetry() async throws {
        let container = try AppContainer(inMemory: true)
        try container.userProfileService.createProfile(ProfileTestFixtures.sampleDraft)

        let aiService = PhotoCapturingAIService()
        aiService.estimateFoodError = AIServiceError.networkUnavailable
        let model = CoachModel(
            actionCenter: container.actionCenter,
            dailyLogReader: container.dailyLogService,
            healthActivityQuery: container.healthActivityQueryService,
            aiService: aiService,
            userProfileReader: container.userProfileService,
            aiCommandParsingEnabled: true
        )

        XCTAssertTrue(await CoachImageWorkflowTestSupport.stageTestMealPhoto(
            on: model,
            jpeg: Self.makeTestJPEGData(),
            source: .library
        ))
        await model.sendCurrentMessage()

        XCTAssertNotNil(model.messages.first { $0.role == .user }?.mealPhotoJPEG)
        XCTAssertNotNil(model.messages.first { $0.role == .user }?.imageAttachment)
        XCTAssertTrue(model.messages.contains { $0.photoAnalysisLink?.isFailure == true })
        XCTAssertTrue(model.messages.last?.text.contains("couldn't reach Coach") == true)
        XCTAssertNil(model.pendingConfirmation)

        aiService.estimateFoodError = nil
        let userMessageID = try XCTUnwrap(model.messages.first { $0.role == .user }?.id)
        await model.retryMealPhotoAnalysis(for: userMessageID)

        XCTAssertEqual(aiService.analyzeMealImageCallCount, 2)
        XCTAssertNotNil(model.pendingConfirmation)
        XCTAssertFalse(model.messages.contains { $0.photoAnalysisLink?.isFailure == true })
        XCTAssertTrue(model.messages.contains { $0.photoAnalysisLink?.isFailure == false })
    }

    func testLowConfidenceClarificationRecommissionsWithSameImage() async throws {
        let container = try AppContainer(inMemory: true)
        try container.userProfileService.createProfile(ProfileTestFixtures.sampleDraft)

        let aiService = ClarifyingPhotoAIService()
        let model = CoachModel(
            actionCenter: container.actionCenter,
            dailyLogReader: container.dailyLogService,
            healthActivityQuery: container.healthActivityQueryService,
            aiService: aiService,
            userProfileReader: container.userProfileService,
            aiCommandParsingEnabled: true
        )

        XCTAssertTrue(await CoachImageWorkflowTestSupport.stageTestMealPhoto(
            on: model,
            jpeg: Self.makeTestJPEGData(),
            source: .library
        ))
        await model.sendCurrentMessage()

        XCTAssertTrue(model.awaitingPhotoClarification)
        XCTAssertNotNil(model.pendingConfirmation)

        let userMessageID = try XCTUnwrap(model.messages.first { $0.role == .user }?.id)
        model.inputText = "It was barley, not rice."
        await model.sendCurrentMessage()

        XCTAssertEqual(aiService.analyzeMealImageCallCount, 2)
        XCTAssertEqual(aiService.lastClarification, "It was barley, not rice.")
        XCTAssertFalse(model.messages.filter { $0.photoAnalysisLink?.kind == .result }.count > 2)
        XCTAssertNotNil(model.pendingConfirmation)
    }

    func testGenericPhotoResponseDoesNotCreateDraftCard() async throws {
        let container = try AppContainer(inMemory: true)
        try container.userProfileService.createProfile(ProfileTestFixtures.sampleDraft)

        let aiService = GenericFallbackPhotoAIService()
        let model = CoachModel(
            actionCenter: container.actionCenter,
            dailyLogReader: container.dailyLogService,
            healthActivityQuery: container.healthActivityQueryService,
            aiService: aiService,
            userProfileReader: container.userProfileService,
            aiCommandParsingEnabled: true
        )

        XCTAssertTrue(await CoachImageWorkflowTestSupport.stageTestMealPhoto(
            on: model,
            jpeg: Self.makeTestJPEGData(),
            source: .library
        ))
        await model.sendCurrentMessage()

        XCTAssertNil(model.pendingConfirmation)
        XCTAssertTrue(model.messages.contains { $0.photoAnalysisLink?.isFailure == true })
    }

    func testPhotoRetryPreservesDraftCardIdentity() async throws {
        let container = try AppContainer(inMemory: true)
        try container.userProfileService.createProfile(ProfileTestFixtures.sampleDraft)

        let aiService = RetryImprovingPhotoAIService()
        let model = CoachModel(
            actionCenter: container.actionCenter,
            dailyLogReader: container.dailyLogService,
            healthActivityQuery: container.healthActivityQueryService,
            aiService: aiService,
            userProfileReader: container.userProfileService,
            aiCommandParsingEnabled: true
        )

        XCTAssertTrue(await CoachImageWorkflowTestSupport.stageTestMealPhoto(
            on: model,
            jpeg: Self.makeTestJPEGData(),
            source: .library
        ))
        await model.sendCurrentMessage()

        guard case .food(let firstDraft) = model.pendingConfirmation else {
            return XCTFail("Expected pending food draft")
        }
        XCTAssertEqual(firstDraft.confidence, .low)
        let originalID = firstDraft.id
        let userMessageID = try XCTUnwrap(firstDraft.relatedPhotoUserMessageID)

        await model.retryMealPhotoAnalysis(for: userMessageID)

        guard case .food(let secondDraft) = model.pendingConfirmation else {
            return XCTFail("Expected pending food draft after retry")
        }
        XCTAssertEqual(secondDraft.id, originalID)
        XCTAssertEqual(secondDraft.confidence, .medium)
        XCTAssertEqual(aiService.analyzeMealImageCallCount, 2)
    }

    func testFailedPhotoRetryClearsLinkedDraftCard() async throws {
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

        XCTAssertTrue(await CoachImageWorkflowTestSupport.stageTestMealPhoto(
            on: model,
            jpeg: Self.makeTestJPEGData(),
            source: .library
        ))
        await model.sendCurrentMessage()
        XCTAssertNotNil(model.pendingConfirmation)

        aiService.estimateFoodError = AIServiceError.networkUnavailable
        let userMessageID = try XCTUnwrap(model.messages.first { $0.role == .user }?.id)
        await model.retryMealPhotoAnalysis(for: userMessageID)

        XCTAssertNil(model.pendingConfirmation)
        XCTAssertTrue(model.messages.contains { $0.photoAnalysisLink?.isFailure == true })
    }

    func testTodayScanFoodVisibleWhenPipelineReady() {
        XCTAssertTrue(TodayPhotoScanAvailability.isPipelineReady)
        XCTAssertTrue(TodayQuickActionPolicy.isVisible(.scanFood))
        XCTAssertEqual(
            TodayQuickActionPolicy.configuration().showsScanMeal,
            TodayPhotoScanAvailability.isPipelineReady
        )
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

    private static func makeTestJPEGData(color: UIColor = .orange) -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 12, height: 12))
        let image = renderer.image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 12, height: 12))
        }
        return image.jpegData(compressionQuality: 0.85)!
    }
}

private final class PhotoCapturingAIService: AIServiceProtocol, @unchecked Sendable {
    var estimateFoodCallCount = 0
    var analyzeMealImageCallCount = 0
    var lastImageJPEGData: Data?
    var lastPrompt: String?
    var lastClarification: String?
    var estimateFoodError: Error?

    func classifyCoachIntent(
        _ text: String,
        context: CoachContextPacketV2,
        config: CoachModelConfig
    ) async throws -> CoachIntentResult {
        CoachMealPhotoPipeline.photoAnalysisIntentResult
    }

    func estimateFood(
        prompt: String,
        context: CoachContextPacketV2,
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

    func analyzeMealImage(request: AIMealImageAnalysisRequest) async throws -> AIMealImageAnalysisResponse {
        analyzeMealImageCallCount += 1
        if let data = Data(base64Encoded: request.image.base64) {
            lastImageJPEGData = data
        }
        lastPrompt = request.message
        lastClarification = request.clarification
        if let estimateFoodError { throw estimateFoodError }
        return AIMealImageAnalysisResponse(
            summary: "Photo meal",
            items: [
                AIMealImageAnalysisItem(
                    name: "Photo meal",
                    quantity: "1 serving",
                    calories: 420,
                    protein: 28,
                    carbs: 35,
                    fat: 14,
                    confidence: .medium,
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
            clarifyingQuestion: nil
        )
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

private final class GenericFallbackPhotoAIService: AIServiceProtocol, @unchecked Sendable {
    func classifyCoachIntent(
        _ text: String,
        context: CoachContextPacketV2,
        config: CoachModelConfig
    ) async throws -> CoachIntentResult {
        CoachMealPhotoPipeline.photoAnalysisIntentResult
    }

    func analyzeMealImage(request: AIMealImageAnalysisRequest) async throws -> AIMealImageAnalysisResponse {
        AIMealImageAnalysisResponse(
            summary: "Fruit + toast with spread",
            items: [
                AIMealImageAnalysisItem(
                    name: "generic meal",
                    quantity: "1 serving",
                    calories: 220,
                    protein: 5,
                    carbs: 38,
                    fat: 6.5,
                    confidence: .low,
                    assumptions: ["Fallback guess"]
                )
            ],
            total: AIMealImageAnalysisTotals(calories: 220, protein: 5, carbs: 38, fat: 6.5),
            needsUserReview: true,
            clarifyingQuestion: nil
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

    func generateDailyReviewText(input: DailyReviewAIInput, context: CoachContextPacketV2) async throws -> AICoachResponse {
        throw AIServiceError.backendUnavailable
    }

    func parseCommand(_ text: String, context: CoachContextPacketV2) async throws -> AIParsedCommand {
        throw AIServiceError.backendUnavailable
    }
}

private final class RetryImprovingPhotoAIService: AIServiceProtocol, @unchecked Sendable {
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
        return AIMealImageAnalysisResponse(
            summary: "Grain bowl",
            items: [
                AIMealImageAnalysisItem(
                    name: "Grain bowl",
                    quantity: "1 bowl",
                    calories: 420,
                    protein: 18,
                    carbs: 55,
                    fat: 12,
                    confidence: confidence,
                    assumptions: ["Brown rice base"]
                )
            ],
            total: AIMealImageAnalysisTotals(calories: 420, protein: 18, carbs: 55, fat: 12),
            needsUserReview: true,
            clarifyingQuestion: confidence == .low ? "Was this rice or barley?" : nil
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

    func generateDailyReviewText(input: DailyReviewAIInput, context: CoachContextPacketV2) async throws -> AICoachResponse {
        throw AIServiceError.backendUnavailable
    }

    func parseCommand(_ text: String, context: CoachContextPacketV2) async throws -> AIParsedCommand {
        throw AIServiceError.backendUnavailable
    }
}

private final class ClarifyingPhotoAIService: AIServiceProtocol, @unchecked Sendable {
    var analyzeMealImageCallCount = 0
    var lastClarification: String?

    func classifyCoachIntent(
        _ text: String,
        context: CoachContextPacketV2,
        config: CoachModelConfig
    ) async throws -> CoachIntentResult {
        CoachMealPhotoPipeline.photoAnalysisIntentResult
    }

    func analyzeMealImage(request: AIMealImageAnalysisRequest) async throws -> AIMealImageAnalysisResponse {
        analyzeMealImageCallCount += 1
        lastClarification = request.clarification
        let confidence: AIConfidence = request.clarification == nil ? .low : .medium
        return AIMealImageAnalysisResponse(
            summary: request.clarification == nil ? "Grain bowl" : "Barley bowl",
            items: [
                AIMealImageAnalysisItem(
                    name: request.clarification == nil ? "Grain bowl" : "Barley bowl",
                    quantity: "1 bowl",
                    calories: 420,
                    protein: 18,
                    carbs: 55,
                    fat: 12,
                    confidence: confidence,
                    assumptions: []
                )
            ],
            total: AIMealImageAnalysisTotals(
                calories: 420,
                protein: 18,
                carbs: 55,
                fat: 12
            ),
            needsUserReview: true,
            clarifyingQuestion: request.clarification == nil ? "Was this rice or barley?" : nil
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
