//
//  CoachImageWorkflowE2ETests.swift
//  Fitness CoachTests
//
//  End-to-end coverage for the Coach image pick → send → analyze → retry workflow.
//

import UIKit
import XCTest
@testable import Fitness_Coach

@MainActor
final class CoachImageWorkflowE2ETests: XCTestCase {

    // MARK: - 1. Pick image from library

    func testLibraryPickShowsImageInComposerWithSendEnabled() async throws {
        let container = try AppContainer(inMemory: true)
        let model = try CoachImageWorkflowTestSupport.makeCoach(
            aiService: WorkflowCapturingPhotoAIService(),
            container: container
        ).0

        XCTAssertTrue(await CoachImageWorkflowTestSupport.stageTestMealPhoto(
            on: model,
            jpeg: CoachImageWorkflowTestSupport.makeTestJPEG(),
            source: .library
        ))

        XCTAssertNotNil(model.inputState.pendingImage)
        XCTAssertEqual(model.inputState.pendingImage?.source, .library)
        XCTAssertFalse(model.inputState.pendingImage?.thumbnail.isEmpty == true)
        XCTAssertTrue(model.inputState.canSend)
        XCTAssertTrue(model.messages.isEmpty)
    }

    func testRemoveStagedLibraryImageClearsComposerAndDisablesSend() async throws {
        let container = try AppContainer(inMemory: true)
        let model = try CoachImageWorkflowTestSupport.makeCoach(
            aiService: WorkflowCapturingPhotoAIService(),
            container: container
        ).0

        XCTAssertTrue(await CoachImageWorkflowTestSupport.stageTestMealPhoto(
            on: model,
            jpeg: CoachImageWorkflowTestSupport.makeTestJPEG(),
            source: .library
        ))
        model.removeStagedMealPhoto()

        XCTAssertNil(model.inputState.pendingImage)
        XCTAssertNil(model.inputState.pendingImage?.uploadData)
        XCTAssertFalse(model.inputState.canSend)
    }

    func testEmptyComposerCannotSendWithoutTextOrImage() throws {
        let container = try AppContainer(inMemory: true)
        let model = try CoachImageWorkflowTestSupport.makeCoach(
            aiService: WorkflowCapturingPhotoAIService(),
            container: container
        ).0

        XCTAssertFalse(model.inputState.canSend)
        XCTAssertTrue(model.inputState.canStartImageSelection)
    }

    // MARK: - 2. Take photo

    func testCameraOutputAppearsInComposer() async throws {
        let container = try AppContainer(inMemory: true)
        let model = try CoachImageWorkflowTestSupport.makeCoach(
            aiService: WorkflowCapturingPhotoAIService(),
            container: container
        ).0

        XCTAssertTrue(await CoachImageWorkflowTestSupport.stageTestMealPhoto(
            on: model,
            jpeg: CoachImageWorkflowTestSupport.makeTestJPEG(color: .systemBlue),
            source: .camera
        ))

        XCTAssertEqual(model.inputState.pendingImage?.source, .camera)
        XCTAssertTrue(model.inputState.canSend)
        XCTAssertNotNil(model.inputState.pendingImage?.uploadData)
    }

    func testCameraPhotoSendCompletesSuccessfully() async throws {
        let aiService = WorkflowCapturingPhotoAIService()
        let model = try CoachImageWorkflowTestSupport.makeCoach(aiService: aiService).0

        XCTAssertTrue(await CoachImageWorkflowTestSupport.stageTestMealPhoto(
            on: model,
            jpeg: CoachImageWorkflowTestSupport.makeTestJPEG(),
            source: .camera
        ))
        await model.sendCurrentMessage()

        XCTAssertEqual(aiService.analyzeMealImageCallCount, 1)
        XCTAssertNotNil(model.pendingConfirmation)
        XCTAssertNotNil(model.messages.first { $0.role == .user }?.mealPhotoJPEG)
    }

    // MARK: - 3. Image-only send

    func testSendCurrentMessageDoesNotAbortWhenProcessingLockAcquired() async throws {
        let aiService = WorkflowCapturingPhotoAIService()
        let model = try CoachImageWorkflowTestSupport.makeCoach(aiService: aiService).0
        let jpeg = CoachImageWorkflowTestSupport.makeTestJPEG()

        model.inputText = "Estimate this food caloric amount"
        XCTAssertTrue(await CoachImageWorkflowTestSupport.stageTestMealPhoto(on: model, jpeg: jpeg, source: .library))
        await model.sendCurrentMessage()

        XCTAssertEqual(aiService.analyzeMealImageCallCount, 1)
        XCTAssertNotNil(model.messages.first { $0.role == .user }?.mealPhotoJPEG)
        XCTAssertNotNil(model.pendingConfirmation)
    }

    func testImageOnlySendCreatesUserBubbleBackendPayloadAndMealDraft() async throws {
        let aiService = WorkflowCapturingPhotoAIService()
        let model = try CoachImageWorkflowTestSupport.makeCoach(aiService: aiService).0
        let jpeg = CoachImageWorkflowTestSupport.makeTestJPEG()

        XCTAssertTrue(await CoachImageWorkflowTestSupport.stageTestMealPhoto(on: model, jpeg: jpeg, source: .library))
        await model.sendCurrentMessage()

        let userMessage = try XCTUnwrap(model.messages.first { $0.role == .user })
        XCTAssertNotNil(userMessage.imageAttachment)
        XCTAssertNotNil(userMessage.mealPhotoJPEG)
        XCTAssertTrue(userMessage.text.isEmpty)

        XCTAssertEqual(aiService.analyzeMealImageCallCount, 1)
        XCTAssertEqual(aiService.receivedImagePayloads.count, 1)
        XCTAssertTrue(CoachMealPhotoPipeline.hasImagePayload(aiService.receivedImagePayloads.first))

        XCTAssertNotNil(model.pendingConfirmation)
        guard case .food(let draft) = model.pendingConfirmation else {
            return XCTFail("Expected food draft card")
        }
        XCTAssertEqual(draft.mealDraft.displayName, "Photo meal")

        XCTAssertTrue(model.messages.contains { $0.photoAnalysisLink?.kind == .result })
        XCTAssertNil(model.inputState.pendingImage?.uploadData)
    }

    func testImageOnlySendShowsPendingAssistantStateWhileAnalyzing() async throws {
        let aiService = HoldablePhotoAIService()
        let model = try CoachImageWorkflowTestSupport.makeCoach(aiService: aiService).0

        XCTAssertTrue(await CoachImageWorkflowTestSupport.stageTestMealPhoto(
            on: model,
            jpeg: CoachImageWorkflowTestSupport.makeTestJPEG(),
            source: .library
        ))

        let sendTask = Task { await model.sendCurrentMessage() }
        let enteredSending = await AsyncTestSupport.waitUntil {
            model.isSending && aiService.analyzeMealImageCallCount == 1
        }
        XCTAssertTrue(enteredSending, "Expected pending assistant state while analysis runs")

        aiService.releaseAll()
        await sendTask.value

        XCTAssertFalse(model.isSending)
        XCTAssertNotNil(model.pendingConfirmation)
    }

    // MARK: - 4. Text + image send

    func testTextAndImageSendShowsBothInBubbleAndBackend() async throws {
        let aiService = WorkflowCapturingPhotoAIService()
        let model = try CoachImageWorkflowTestSupport.makeCoach(aiService: aiService).0
        let jpeg = CoachImageWorkflowTestSupport.makeTestJPEG()

        model.inputText = "Lunch bowl"
        XCTAssertTrue(await CoachImageWorkflowTestSupport.stageTestMealPhoto(on: model, jpeg: jpeg, source: .library))
        await model.sendCurrentMessage()

        let userMessage = try XCTUnwrap(model.messages.first { $0.role == .user })
        XCTAssertEqual(userMessage.text, "Lunch bowl")
        XCTAssertNotNil(userMessage.mealPhotoJPEG)
        XCTAssertNotNil(userMessage.imageAttachment)

        XCTAssertEqual(aiService.receivedPrompts.last ?? nil, "Lunch bowl")
        XCTAssertEqual(aiService.receivedImagePayloads.count, 1)
        if let prepared = CoachImageWorkflowTestSupport.processedUploadData(from: jpeg) {
            XCTAssertEqual(aiService.receivedImagePayloads.first, prepared)
        } else {
            XCTFail("Expected prepared JPEG")
        }
    }

    // MARK: - 5. Failure

    func testAnalysisFailureKeepsUserImageShowsErrorAndNoDraftCard() async throws {
        let aiService = WorkflowCapturingPhotoAIService()
        aiService.injectedError = AIServiceError.networkUnavailable
        let model = try CoachImageWorkflowTestSupport.makeCoach(aiService: aiService).0

        XCTAssertTrue(await CoachImageWorkflowTestSupport.stageTestMealPhoto(
            on: model,
            jpeg: CoachImageWorkflowTestSupport.makeTestJPEG(),
            source: .library
        ))
        await model.sendCurrentMessage()

        let userMessage = try XCTUnwrap(model.messages.first { $0.role == .user })
        XCTAssertNotNil(userMessage.mealPhotoJPEG)
        XCTAssertNotNil(userMessage.imageAttachment)

        XCTAssertNil(model.pendingConfirmation)
        let failureMessage = try XCTUnwrap(
            model.messages.first { $0.photoAnalysisLink?.kind == .failure }
        )
        XCTAssertTrue(failureMessage.text.contains("couldn't reach Coach"))
        XCTAssertNotNil(failureMessage.mealPhotoAnalysisFailure)
    }

    // MARK: - 6. Retry

    func testRetryReusesSameImageAndUpdatesSessionResults() async throws {
        let aiService = WorkflowCapturingPhotoAIService()
        aiService.injectedError = AIServiceError.networkUnavailable
        let model = try CoachImageWorkflowTestSupport.makeCoach(aiService: aiService).0
        let jpeg = CoachImageWorkflowTestSupport.makeTestJPEG()

        XCTAssertTrue(await CoachImageWorkflowTestSupport.stageTestMealPhoto(on: model, jpeg: jpeg, source: .library))
        await model.sendCurrentMessage()

        let userMessageID = try XCTUnwrap(model.messages.first { $0.role == .user }?.id)
        let originalPayload = try XCTUnwrap(aiService.receivedImagePayloads.first)
        XCTAssertTrue(model.messages.contains { $0.photoAnalysisLink?.kind == .failure })

        aiService.injectedError = nil
        await model.retryMealPhotoAnalysis(for: userMessageID)

        XCTAssertEqual(aiService.analyzeMealImageCallCount, 2)
        XCTAssertEqual(aiService.receivedImagePayloads.count, 2)
        XCTAssertEqual(aiService.receivedImagePayloads[1], originalPayload)
        XCTAssertFalse(model.messages.contains { $0.photoAnalysisLink?.kind == .failure })
        XCTAssertNotNil(model.pendingConfirmation)
        XCTAssertTrue(model.messages.contains { $0.photoAnalysisLink?.kind == .result })
    }

    func testRetryPreservesDraftCardIdentityOnImprovement() async throws {
        let aiService = RetryImprovingWorkflowAIService()
        let model = try CoachImageWorkflowTestSupport.makeCoach(aiService: aiService).0

        XCTAssertTrue(await CoachImageWorkflowTestSupport.stageTestMealPhoto(
            on: model,
            jpeg: CoachImageWorkflowTestSupport.makeTestJPEG(),
            source: .library
        ))
        await model.sendCurrentMessage()

        guard case .food(let firstDraft) = model.pendingConfirmation else {
            return XCTFail("Expected initial draft")
        }
        XCTAssertEqual(firstDraft.confidence, .low)
        let originalID = firstDraft.id
        let userMessageID = try XCTUnwrap(firstDraft.relatedPhotoUserMessageID)

        await model.retryMealPhotoAnalysis(for: userMessageID)

        guard case .food(let secondDraft) = model.pendingConfirmation else {
            return XCTFail("Expected draft after successful retry")
        }
        XCTAssertEqual(secondDraft.id, originalID)
        XCTAssertEqual(secondDraft.confidence, .medium)
        XCTAssertEqual(aiService.analyzeMealImageCallCount, 2)
    }

    // MARK: - 7. Remove image

    func testRemoveStagedImageBeforeSendDoesNotTransmitImageLater() async throws {
        let aiService = WorkflowCapturingPhotoAIService()
        let model = try CoachImageWorkflowTestSupport.makeCoach(aiService: aiService).0

        XCTAssertTrue(await CoachImageWorkflowTestSupport.stageTestMealPhoto(
            on: model,
            jpeg: CoachImageWorkflowTestSupport.makeTestJPEG(),
            source: .library
        ))
        model.removeStagedMealPhoto()
        model.inputText = "log water"
        await model.sendCurrentMessage()

        XCTAssertEqual(aiService.analyzeMealImageCallCount, 0)
        XCTAssertEqual(aiService.receivedImagePayloads.count, 0)
        XCTAssertNil(model.messages.first { $0.mealPhotoJPEG != nil })
    }

    // MARK: - 8. Rapid add/remove

    func testRapidAddRemoveDoesNotLeaveStaleAttachmentOrThumbnail() async throws {
        let aiService = WorkflowCapturingPhotoAIService()
        let model = try CoachImageWorkflowTestSupport.makeCoach(aiService: aiService).0
        let jpeg = CoachImageWorkflowTestSupport.makeTestJPEG()

        for index in 0..<25 {
            let source: CoachInputAttachmentSource = index.isMultiple(of: 2) ? .library : .camera
            await CoachImageWorkflowTestSupport.stageTestMealPhoto(on: model, jpeg: jpeg, source: source)
            model.removeStagedMealPhoto()
        }

        XCTAssertNil(model.inputState.pendingImage)
        XCTAssertNil(model.inputState.pendingImage?.uploadData)
        XCTAssertNil(model.inputState.imageError)
        XCTAssertFalse(model.inputState.canSend)
        XCTAssertTrue(model.inputState.canStartImageSelection)

        model.inputText = "hello"
        await model.sendCurrentMessage()
        XCTAssertEqual(aiService.analyzeMealImageCallCount, 0)
    }

    func testRapidAddRemoveThenSendImageOnlyUsesLatestAttachment() async throws {
        let aiService = WorkflowCapturingPhotoAIService()
        let model = try CoachImageWorkflowTestSupport.makeCoach(aiService: aiService).0
        let first = CoachImageWorkflowTestSupport.makeTestJPEG(color: .red)
        let second = CoachImageWorkflowTestSupport.makeTestJPEG(color: .green)

        XCTAssertTrue(await CoachImageWorkflowTestSupport.stageTestMealPhoto(on: model, jpeg: first, source: .library))
        model.removeStagedMealPhoto()
        XCTAssertTrue(await CoachImageWorkflowTestSupport.stageTestMealPhoto(on: model, jpeg: second, source: .camera))
        await model.sendCurrentMessage()

        XCTAssertEqual(aiService.analyzeMealImageCallCount, 1)
        if let preparedSecond = CoachImageWorkflowTestSupport.processedUploadData(from: second) {
            XCTAssertEqual(aiService.receivedImagePayloads.first, preparedSecond)
        } else {
            XCTFail("Expected prepared second JPEG")
        }
        XCTAssertNotEqual(aiService.receivedImagePayloads.first, first)
    }
}
