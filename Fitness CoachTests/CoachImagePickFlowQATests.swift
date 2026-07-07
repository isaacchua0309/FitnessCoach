//
//  CoachImagePickFlowQATests.swift
//  Fitness CoachTests
//
//  Regression coverage for the 18-step Coach image manual QA checklist.
//

import UIKit
import XCTest
@testable import Fitness_Coach

@MainActor
final class CoachImagePickFlowQATests: XCTestCase {

    // MARK: - Stale import guards (remove during processing, navigate away)

    func testStaleImportSuccessAfterRemoveDoesNotRestageImage() async throws {
        let container = try AppContainer(inMemory: true)
        let model = makeModel(container: container)
        let image = Self.makeTestImage(size: CGSize(width: 720, height: 540))
        let localReferenceID = UUID()

        XCTAssertTrue(model.beginPendingImageProcessing(source: .library))
        model.attachPendingImageLocalReference(localReferenceID)
        model.removeStagedMealPhoto()

        guard case .success(let processed) = CoachImagePipeline.process(image: image) else {
            return XCTFail("Expected pipeline success")
        }

        let staged = await model.stagePipelineProcessedPhoto(
            CoachImagePipeline.ProcessedImageImport(
                processed: processed,
                originalEstimatedBytes: 1_200_000,
                localReferenceID: localReferenceID
            ),
            source: .library
        )

        XCTAssertFalse(staged)
        XCTAssertNil(model.inputState.pendingImage)
        XCTAssertNil(model.inputState.imageError)
    }

    func testStaleImportFailureAfterRemoveDoesNotSetComposerError() throws {
        let container = try AppContainer(inMemory: true)
        let model = makeModel(container: container)

        XCTAssertTrue(model.beginPendingImageProcessing(source: .library))
        model.removeStagedMealPhoto()
        model.failPendingImageProcessing(.encodingFailed)

        XCTAssertNil(model.inputState.pendingImage)
        XCTAssertNil(model.inputState.imageError)
    }

    func testSimulatedNavigateAwayDuringProcessingAllowsLaterDiscard() async throws {
        let container = try AppContainer(inMemory: true)
        let model = makeModel(container: container)
        let flow = CoachImagePickFlowController()
        let image = Self.makeTestImage(size: CGSize(width: 900, height: 700))
        let localReferenceID = UUID()

        flow.setStateForTests(.processingImage(.library))
        XCTAssertTrue(model.beginPendingImageProcessing(source: .library))
        model.storePendingImageLocalSource(image)
        model.attachPendingImageLocalReference(localReferenceID)

        let importTask = Task {
            await CoachImagePipeline.processImportedImage(
                image,
                source: .library,
                originalEstimatedBytes: 2_000_000,
                localReferenceID: localReferenceID
            )
        }

        model.removeStagedMealPhoto()
        flow.handleAttachmentRemoved()

        guard case .success(let imported) = await importTask.value else {
            return XCTFail("Expected import success")
        }

        let staged = await model.stagePipelineProcessedPhoto(imported, source: .library)
        XCTAssertFalse(staged)
        XCTAssertNil(model.inputState.pendingImage)
        XCTAssertEqual(flow.state, .idle)
    }

    // MARK: - Camera / remove / replace

    func testRemoveThenSecondCameraCaptureStagesLatestImage() async throws {
        let container = try AppContainer(inMemory: true)
        let model = makeModel(container: container)
        let flow = CoachImagePickFlowController()
        let first = Self.makeTestImage(size: CGSize(width: 400, height: 400), color: .red)
        let second = Self.makeTestImage(size: CGSize(width: 500, height: 500), color: .green)

        flow.setStateForTests(.pickerPresented(.camera))
        await flow.handleCameraResult(.success(first), model: model)
        let firstUpload = try XCTUnwrap(model.inputState.pendingImage?.uploadData)

        model.removeStagedMealPhoto()
        flow.handleAttachmentRemoved()

        flow.setStateForTests(.pickerPresented(.camera))
        await flow.handleCameraResult(.success(second), model: model)

        XCTAssertNotEqual(model.inputState.pendingImage?.uploadData, firstUpload)
        XCTAssertEqual(model.inputState.pendingImage?.source, .camera)
        XCTAssertEqual(model.inputState.pendingImage?.status, .ready)
    }

    // MARK: - Send matrix (text / image / combined / retry / clear)

    func testTextOnlySendDoesNotInvokeImageAnalysis() async throws {
        let aiService = WorkflowCapturingPhotoAIService()
        let model = try CoachImageWorkflowTestSupport.makeCoach(aiService: aiService).0

        model.inputText = "log water"
        await model.sendCurrentMessage()

        XCTAssertEqual(aiService.analyzeMealImageCallCount, 0)
        XCTAssertNil(model.inputState.pendingImage)
    }

    func testSuccessfulImageSendClearsComposerState() async throws {
        let aiService = WorkflowCapturingPhotoAIService()
        let model = try CoachImageWorkflowTestSupport.makeCoach(aiService: aiService).0
        let flow = CoachImagePickFlowController()
        let image = Self.makeTestImage(size: CGSize(width: 640, height: 480))

        flow.setStateForTests(.pickerPresented(.camera))
        await flow.handleCameraResult(.success(image), model: model)
        await model.sendCurrentMessage()

        XCTAssertNil(model.inputState.pendingImage)
        XCTAssertTrue(model.inputText.isEmpty)
        XCTAssertEqual(aiService.analyzeMealImageCallCount, 1)
        XCTAssertNotNil(model.pendingConfirmation)
    }

    func testNetworkFailureRetryTransmitsOncePerAttempt() async throws {
        let aiService = WorkflowCapturingPhotoAIService()
        aiService.injectedError = AIServiceError.networkUnavailable
        let model = try CoachImageWorkflowTestSupport.makeCoach(aiService: aiService).0

        let staged = await CoachImageWorkflowTestSupport.stageTestMealPhoto(
            on: model,
            jpeg: CoachImageWorkflowTestSupport.makeTestJPEG(),
            source: .library
        )
        XCTAssertTrue(staged)
        await model.sendCurrentMessage()

        let userMessageID = try XCTUnwrap(model.messages.first { $0.role == .user }?.id)
        aiService.injectedError = nil
        await model.retryMealPhotoAnalysis(for: userMessageID)

        XCTAssertEqual(aiService.analyzeMealImageCallCount, 2)
        XCTAssertNotNil(model.pendingConfirmation)
    }

    // MARK: - Rapid interactions

    func testRapidRemoveDuringProcessingDoesNotLeaveStaleThumbnail() async throws {
        let container = try AppContainer(inMemory: true)
        let model = makeModel(container: container)
        let flow = CoachImagePickFlowController()
        let jpeg = CoachImageWorkflowTestSupport.makeTestJPEG()

        for _ in 0..<10 {
            flow.setStateForTests(.pickerPresented(.library))
            XCTAssertTrue(model.beginPendingImageProcessing(source: .library))
            model.removeStagedMealPhoto()
            flow.handleAttachmentRemoved()
            await CoachImageWorkflowTestSupport.stageTestMealPhoto(on: model, jpeg: jpeg, source: .library)
            model.removeStagedMealPhoto()
            flow.handleAttachmentRemoved()
        }

        XCTAssertNil(model.inputState.pendingImage)
        XCTAssertNil(model.inputState.imageError)
        XCTAssertEqual(flow.state, .idle)
    }

    func testRapidSendTapsTransmitOnlyOnceWhileImageReady() async throws {
        let aiService = HoldablePhotoAIService()
        let model = try CoachImageWorkflowTestSupport.makeCoach(aiService: aiService).0
        let flow = CoachImagePickFlowController()
        let image = Self.makeTestImage(size: CGSize(width: 320, height: 240))

        flow.setStateForTests(.pickerPresented(.camera))
        await flow.handleCameraResult(.success(image), model: model)

        async let first = model.sendCurrentMessage()
        async let second = model.sendCurrentMessage()
        async let third = model.sendCurrentMessage()
        await first
        await second
        await third

        XCTAssertEqual(aiService.analyzeMealImageCallCount, 1)
        XCTAssertNil(model.inputState.pendingImage)
    }

    func testSendBlockedWhileImageProcessing() async throws {
        let container = try AppContainer(inMemory: true)
        let model = makeModel(container: container)

        XCTAssertTrue(model.beginPendingImageProcessing(source: .library))
        XCTAssertFalse(model.inputState.canSend)
    }

    // MARK: - Large / screenshot-style inputs via pipeline

    func testLargeIPhoneStylePhotoProcessesWithoutComposerError() async throws {
        let container = try AppContainer(inMemory: true)
        let model = makeModel(container: container)
        let image = Self.makeTestImage(size: CGSize(width: 4_032, height: 3_024))
        let localReferenceID = UUID()

        XCTAssertTrue(model.beginPendingImageProcessing(source: .library))
        model.attachPendingImageLocalReference(localReferenceID)

        guard case .success(let imported) = await CoachImagePipeline.processImportedImage(
            image,
            source: .library,
            originalEstimatedBytes: 6_500_000,
            localReferenceID: localReferenceID
        ) else {
            return XCTFail("Expected large photo to process")
        }

        let staged = await model.stagePipelineProcessedPhoto(imported, source: .library)
        XCTAssertTrue(staged)
        XCTAssertEqual(model.inputState.pendingImage?.status, .ready)
        XCTAssertNil(model.inputState.imageError)
        XCTAssertLessThanOrEqual(
            model.inputState.pendingImage?.byteSize ?? .max,
            CoachImageUploadConfig.default.maxUploadBytes
        )
    }

    func testScreenshotAspectRatioProcessesToReadyState() async throws {
        let container = try AppContainer(inMemory: true)
        let model = makeModel(container: container)
        let image = Self.makeTestImage(size: CGSize(width: 1_179, height: 2_556))
        let localReferenceID = UUID()

        XCTAssertTrue(model.beginPendingImageProcessing(source: .library))
        model.attachPendingImageLocalReference(localReferenceID)

        guard case .success(let imported) = await CoachImagePipeline.processImportedImage(
            image,
            source: .library,
            originalEstimatedBytes: 900_000,
            localReferenceID: localReferenceID
        ) else {
            return XCTFail("Expected screenshot-style image to process")
        }

        let staged = await model.stagePipelineProcessedPhoto(imported, source: .library)
        XCTAssertTrue(staged)
        XCTAssertTrue(model.inputState.canSend)
    }

    // MARK: - Helpers

    private func makeModel(container: AppContainer) -> CoachModel {
        CoachModelTestFactory.makeModel(
            actionCenter: container.actionCenter,
            dailyLogReader: container.dailyLogService,
            healthActivityQuery: container.healthActivityQueryService
        )
    }

    private static func makeTestImage(
        size: CGSize,
        color: UIColor = .systemOrange
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}
