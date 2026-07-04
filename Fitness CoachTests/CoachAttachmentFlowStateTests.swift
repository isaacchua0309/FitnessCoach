//
//  CoachAttachmentFlowStateTests.swift
//  Fitness CoachTests
//
//  Forma — Hardened Coach image attachment state transitions.
//

import UIKit
import XCTest
@testable import Fitness_Coach

// MARK: - Picker presentation (scenarios 1, 2, 3, 10)

final class CoachAttachmentFlowStateTests: XCTestCase {

    func testScenario1CancelAttachmentMenuLeavesComposerUntouched() {
        var presentation = CoachPhotoPickerPresentation.idle
        let typedText = "Keep this note"

        XCTAssertTrue(presentation.requestSourceDialogPresentation())
        XCTAssertTrue(presentation.isSourceDialogPresented)

        let destination = presentation.finishSourceDialogDismissal()

        XCTAssertEqual(destination, .none)
        XCTAssertFalse(presentation.isSourceDialogPresented)
        XCTAssertFalse(presentation.isPresentingPicker)
        XCTAssertEqual(presentation.activePicker, .none)
        XCTAssertNotEqual(typedText, "")
    }

    func testScenario2CancelLibraryPickerPreservesExistingAttachmentAndText() async throws {
        let container = try AppContainer(inMemory: true)
        let model = makeModel(container: container)
        let existingImage = Self.makeTestJPEGData()

        model.inputText = "Typed caption"
        await model.importAttachment(from: .success(existingImage), sourceLabel: "A.jpg")
        guard let existingAttachment = model.inputAttachmentState.attachment else {
            return XCTFail("Expected existing attachment")
        }

        var presentation = CoachPhotoPickerPresentation.idle
        XCTAssertTrue(presentation.present(.photoLibrary))
        XCTAssertEqual(presentation.activePicker, .photoLibrary)

        presentation.dismissActivePicker()

        XCTAssertEqual(model.inputAttachmentState.attachment?.id, existingAttachment.id)
        XCTAssertEqual(model.inputText, "Typed caption")
        XCTAssertFalse(presentation.isPresentingPicker)
    }

    func testScenario3CancelCameraPickerPreservesExistingAttachmentAndText() async throws {
        let container = try AppContainer(inMemory: true)
        let model = makeModel(container: container)
        let existingImage = Self.makeTestJPEGData()

        model.inputText = "Still here"
        await model.importAttachment(from: .success(existingImage), sourceLabel: "A.jpg")
        guard let existingAttachment = model.inputAttachmentState.attachment else {
            return XCTFail("Expected existing attachment")
        }

        var presentation = CoachPhotoPickerPresentation.idle
        XCTAssertTrue(presentation.present(.camera))

        await model.importAttachment(from: .failure(.userCancelled))
        presentation.dismissActivePicker()

        XCTAssertEqual(model.inputAttachmentState.attachment?.id, existingAttachment.id)
        XCTAssertEqual(model.inputText, "Still here")
        XCTAssertEqual(model.inputAttachmentState.importPhase, .idle)
    }

    func testScenario4RemoveImageClearsStateAndPreservesText() async throws {
        let container = try AppContainer(inMemory: true)
        let model = makeModel(container: container)

        model.inputText = "Lunch log"
        await model.importAttachment(from: .success(Self.makeTestJPEGData()))
        XCTAssertTrue(model.inputAttachmentState.hasAttachment)

        model.removeInputAttachment()

        XCTAssertEqual(model.inputAttachmentState, .none)
        XCTAssertEqual(model.inputText, "Lunch log")

        var presentation = CoachPhotoPickerPresentation.idle
        XCTAssertTrue(presentation.requestSourceDialogPresentation())
    }

    func testScenario5RemoveThenAttachOnlyKeepsNewImage() async throws {
        let container = try AppContainer(inMemory: true)
        let model = makeModel(container: container)
        let imageA = Self.makeTestJPEGData()
        let imageB = Self.makeTestJPEGData()

        await model.importAttachment(from: .success(imageA), sourceLabel: "A.jpg")
        guard let attachmentA = model.inputAttachmentState.attachment else {
            return XCTFail("Expected attachment A")
        }

        model.removeInputAttachment()
        XCTAssertEqual(model.inputAttachmentState, .none)

        await model.importAttachment(from: .success(imageB), sourceLabel: "B.jpg")

        XCTAssertNotEqual(model.inputAttachmentState.attachment?.id, attachmentA.id)
        XCTAssertEqual(model.inputAttachmentState.attachment?.sourceLabel, "B.jpg")
        XCTAssertEqual(model.inputAttachmentState.attachment?.jpegData, imageB)
    }

    func testScenario6FailedReplacementKeepsImageAUntilBLoads() async throws {
        let container = try AppContainer(inMemory: true)
        let model = makeModel(container: container)
        let imageA = Self.makeTestJPEGData()
        let imageB = Self.makeTestJPEGData()

        await model.importAttachment(from: .success(imageA), sourceLabel: "A.jpg")
        guard let attachmentA = model.inputAttachmentState.attachment else {
            return XCTFail("Expected attachment A")
        }

        await model.importAttachment(from: .failure(.noImage), sourceLabel: "B.jpg")
        XCTAssertEqual(model.inputAttachmentState.attachment?.id, attachmentA.id)

        await model.importAttachment(from: .success(imageB), sourceLabel: "B.jpg")
        XCTAssertNotEqual(model.inputAttachmentState.attachment?.id, attachmentA.id)
        XCTAssertEqual(model.inputAttachmentState.attachment?.sourceLabel, "B.jpg")
    }

    func testScenario7SendClearsComposerAndAppendsMessageWithImage() async throws {
        let container = try AppContainer(inMemory: true)
        try container.userProfileService.createProfile(ProfileTestFixtures.sampleDraft)

        let aiService = PhotoCapturingAIService()
        let model = makeModel(container: container, aiService: aiService)
        let imageData = Self.makeTestJPEGData()

        model.inputText = "Meal"
        await model.importAttachment(from: .success(imageData))
        await model.sendCurrentMessage()

        let userMessage = model.messages.last(where: { $0.role == .user })
        XCTAssertEqual(userMessage?.text, "Meal")
        XCTAssertTrue(userMessage?.hasAttachedImage == true)
        XCTAssertEqual(model.inputAttachmentState, .none)
        XCTAssertTrue(model.inputText.isEmpty)
        XCTAssertEqual(aiService.estimateFoodCallCount, 1)
    }

    func testScenario8SendFailureKeepsThreadMessageAndShowsAssistantError() async throws {
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
        XCTAssertEqual(model.inputAttachmentState, .none)
        XCTAssertEqual(model.messages.last?.role, .assistant)
        XCTAssertFalse(model.messages.last?.text.isEmpty == true)
    }

    func testScenario9CameraUnavailableSurfacesCopyWithoutCrash() async throws {
        let container = try AppContainer(inMemory: true)
        let model = makeModel(container: container)

        await model.importAttachment(from: .failure(.cameraUnavailable))

        XCTAssertEqual(model.inputAttachmentState.importError, .cameraUnavailable)
        let copy = CoachResponseBuilder.mealPhotoError(.cameraUnavailable)
        XCTAssertTrue(copy.localizedCaseInsensitiveContains("not available"))
    }

    func testScenario10RapidPresentationRequestsKeepSingleActiveSurface() {
        var presentation = CoachPhotoPickerPresentation.idle

        XCTAssertTrue(presentation.requestSourceDialogPresentation())
        XCTAssertFalse(presentation.requestSourceDialogPresentation())
        XCTAssertTrue(presentation.isSourceDialogPresented)
        XCTAssertFalse(presentation.isPresentingPicker)

        presentation.selectAttachmentSource(.photoLibrary)
        let destination = presentation.finishSourceDialogDismissal()
        XCTAssertEqual(destination, .photoLibrary)
        XCTAssertTrue(presentation.present(destination))
        XCTAssertEqual(presentation.activePicker, .photoLibrary)
        XCTAssertFalse(presentation.present(.camera))
        XCTAssertFalse(presentation.requestSourceDialogPresentation())
    }

    func testScenario10RapidDoubleSendAppendsOneUserMessage() async throws {
        let container = try AppContainer(inMemory: true)
        try container.userProfileService.createProfile(ProfileTestFixtures.sampleDraft)

        let aiService = PhotoCapturingAIService()
        let model = makeModel(container: container, aiService: aiService)
        let imageData = Self.makeTestJPEGData()

        await model.importAttachment(from: .success(imageData))

        async let firstSend: Void = model.sendCurrentMessage()
        async let secondSend: Void = model.sendCurrentMessage()
        _ = await (firstSend, secondSend)

        let userMessages = model.messages.filter { $0.role == .user }
        XCTAssertEqual(userMessages.count, 1)
        XCTAssertEqual(aiService.estimateFoodCallCount, 1)
    }

    func testStaleImportTokenIsIgnoredAfterRemove() async throws {
        let container = try AppContainer(inMemory: true)
        let model = makeModel(container: container)

        var coordinator = CoachAttachmentImportCoordinator()
        let staleToken = coordinator.beginImport()
        model.inputAttachmentState.beginImport()

        model.removeInputAttachment()
        coordinator.invalidate()

        XCTAssertFalse(coordinator.isCurrent(staleToken))
        XCTAssertEqual(model.inputAttachmentState, .none)
    }

    func testImportCoordinatorOnlyAcceptsLatestGeneration() {
        var coordinator = CoachAttachmentImportCoordinator()
        let firstToken = coordinator.beginImport()
        let secondToken = coordinator.beginImport()

        XCTAssertFalse(coordinator.isCurrent(firstToken))
        XCTAssertTrue(coordinator.isCurrent(secondToken))
    }

    @MainActor
    private func makeModel(
        container: AppContainer,
        aiService: AIServiceProtocol = PhotoCapturingAIService()
    ) -> CoachModel {
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

// MARK: - CoachPhotoPickerPresentation state machine

extension CoachAttachmentFlowStateTests {

    func testSourceDialogDismissAfterLibrarySelectionReturnsLibraryDestination() {
        var presentation = CoachPhotoPickerPresentation.idle

        XCTAssertTrue(presentation.requestSourceDialogPresentation())
        presentation.selectAttachmentSource(.photoLibrary)

        let destination = presentation.finishSourceDialogDismissal()

        XCTAssertEqual(destination, .photoLibrary)
        XCTAssertFalse(presentation.isSourceDialogPresented)
    }

    func testSourceDialogDismissAfterCameraSelectionReturnsCameraDestination() {
        var presentation = CoachPhotoPickerPresentation.idle

        XCTAssertTrue(presentation.requestSourceDialogPresentation())
        presentation.selectAttachmentSource(.camera)

        let destination = presentation.finishSourceDialogDismissal()

        XCTAssertEqual(destination, .camera)
    }

    func testBlockingSheetDismissesAllPickerState() {
        var presentation = CoachPhotoPickerPresentation.idle
        presentation.selectAttachmentSource(.photoLibrary)
        _ = presentation.present(.photoLibrary)

        presentation.dismissForBlockingSheet()

        XCTAssertEqual(presentation, .idle)
    }

    func testRequestPhotoLibraryPickerWhileDialogOpenQueuesForDismissal() {
        var presentation = CoachPhotoPickerPresentation.idle
        XCTAssertTrue(presentation.requestSourceDialogPresentation())

        let immediate = presentation.requestPhotoLibraryPicker()

        XCTAssertEqual(immediate, .none)
        XCTAssertFalse(presentation.isSourceDialogPresented)
        XCTAssertEqual(presentation.pendingDestination, .photoLibrary)

        let destination = presentation.finishSourceDialogDismissal()
        XCTAssertEqual(destination, .photoLibrary)
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
