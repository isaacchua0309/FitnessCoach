//
//  CoachImagePickFlowTests.swift
//  Fitness CoachTests
//
//  Coach image pick flow state machine and camera pipeline integration.
//

import UIKit
import XCTest
@testable import Fitness_Coach

@MainActor
final class CoachImagePickFlowTests: XCTestCase {

    func testCameraCaptureStagesPipelineProcessedUpload() async throws {
        let container = try AppContainer(inMemory: true)
        let model = makeModel(container: container)
        let flow = CoachImagePickFlowController()
        let sourceImage = Self.makeTestImage(size: CGSize(width: 1_920, height: 1_080))

        flow.setStateForTests(.pickerPresented(.camera))
        await flow.handleCameraResult(.success(sourceImage), model: model)

        let pending = try XCTUnwrap(model.inputState.pendingImage)
        XCTAssertEqual(pending.source, .camera)
        XCTAssertTrue(pending.isPipelineProcessedUpload)
        XCTAssertFalse(pending.uploadData.isEmpty)
        XCTAssertFalse(pending.thumbnail.isEmpty)
        XCTAssertNotEqual(pending.uploadData, pending.thumbnail)
        XCTAssertEqual(pending.status, .ready)
        XCTAssertTrue(pending.hasValidReadyAttachment)
    }

    func testCameraCaptureSendUsesProcessedUploadBytes() async throws {
        let aiService = WorkflowCapturingPhotoAIService()
        let (model, _) = try CoachImageWorkflowTestSupport.makeCoach(aiService: aiService)
        let flow = CoachImagePickFlowController()
        let sourceImage = Self.makeTestImage(size: CGSize(width: 1_280, height: 960))
        guard case .success(let processed) = CoachImagePipeline.process(image: sourceImage) else {
            return XCTFail("Expected pipeline output")
        }

        flow.setStateForTests(.pickerPresented(.camera))
        await flow.handleCameraResult(.success(sourceImage), model: model)
        await model.sendCurrentMessage()

        XCTAssertEqual(aiService.receivedImagePayloads.last, processed.uploadData)
        XCTAssertNil(model.inputState.pendingImage)
    }

    func testPickFlowControllerCameraSuccessTransitionsThroughProcessingToIdle() async throws {
        let container = try AppContainer(inMemory: true)
        let model = makeModel(container: container)
        let flow = CoachImagePickFlowController()
        let image = Self.makeTestImage(size: CGSize(width: 800, height: 600))

        flow.setStateForTests(.pickerPresented(.camera))
        await flow.handleCameraResult(.success(image), model: model)

        XCTAssertEqual(flow.state, .idle)
        XCTAssertFalse(flow.isCameraPresented)
        XCTAssertFalse(flow.isProcessingImage)
        XCTAssertNotNil(model.inputState.pendingImage)
        XCTAssertEqual(model.inputState.pendingImage?.source, .camera)
        XCTAssertEqual(model.inputState.pendingImage?.status, .ready)
    }

    func testPickFlowControllerPermissionFailureSetsFailedThenIdle() async throws {
        let container = try AppContainer(inMemory: true)
        let model = makeModel(container: container)
        let flow = CoachImagePickFlowController()

        await flow.handleFailureForTests(.cameraPermissionDenied, model: model)

        XCTAssertEqual(flow.state, .idle)
        XCTAssertEqual(model.messages.last?.text, CoachResponseBuilder.mealPhotoError(.cameraPermissionDenied))
    }

    func testPickFlowControllerBlocksSecondPickWhileBusy() async throws {
        let container = try AppContainer(inMemory: true)
        let model = makeModel(container: container)
        let flow = CoachImagePickFlowController()

        flow.setStateForTests(.processingImage(.library))

        XCTAssertEqual(flow.beginPhotoLibraryPick(model: model), .rejectedFlowBusy)
        await flow.beginCameraPick(model: model)
        XCTAssertEqual(flow.state, .processingImage(.library))
    }

    func testRemovingPendingImageResetsPickFlow() async throws {
        let container = try AppContainer(inMemory: true)
        let model = makeModel(container: container)
        let flow = CoachImagePickFlowController()
        flow.setStateForTests(.imageReady)

        flow.setStateForTests(.pickerPresented(.camera))
        await flow.handleCameraResult(
            .success(Self.makeTestImage(size: CGSize(width: 400, height: 400))),
            model: model
        )
        model.removeStagedMealPhoto()
        flow.handleAttachmentRemoved()

        XCTAssertEqual(flow.state, .idle)
        XCTAssertNil(model.inputState.pendingImage)
        XCTAssertTrue(flow.allowsAttachmentPick)
    }

    func testCameraCancelLeavesComposerClean() async throws {
        let container = try AppContainer(inMemory: true)
        let model = makeModel(container: container)
        let flow = CoachImagePickFlowController()

        flow.setStateForTests(.pickerPresented(.camera))
        await flow.handleCameraResult(.failure(.userCancelled), model: model)

        XCTAssertEqual(flow.state, .idle)
        XCTAssertNil(model.inputState.pendingImage)
        XCTAssertTrue(model.inputState.canStartImageSelection)
    }

    func testCameraDismissAfterDeliveredResultDoesNotDropCapture() async throws {
        let container = try AppContainer(inMemory: true)
        let model = makeModel(container: container)
        let flow = CoachImagePickFlowController()
        let image = Self.makeTestImage(size: CGSize(width: 640, height: 480))

        flow.setStateForTests(.pickerPresented(.camera))
        let captureTask = Task {
            await flow.handleCameraResult(.success(image), model: model)
        }
        await Task.yield()
        flow.handleCameraPickerDismissedWithoutResult()
        await captureTask.value

        XCTAssertNotNil(model.inputState.pendingImage)
        XCTAssertEqual(model.inputState.pendingImage?.status, .ready)
        XCTAssertEqual(flow.state, .idle)
    }

    func testLibraryDismissWithoutSelectionReturnsIdle() throws {
        let flow = CoachImagePickFlowController()
        flow.setStateForTests(.pickerPresented(.library))

        flow.handlePhotoLibraryPickerDismissed()

        XCTAssertEqual(flow.state, .idle)
        XCTAssertTrue(flow.allowsAttachmentPick)
    }

    func testLibraryDismissWithPendingSelectionDoesNotCancelPickerState() throws {
        let flow = CoachImagePickFlowController()
        flow.setStateForTests(.pickerPresented(.library))

        flow.markLibrarySelectionReceived(claimedPickID: try XCTUnwrap(flow.activeLibraryPickSessionID))
        flow.handlePhotoLibraryPickerDismissed()

        XCTAssertEqual(flow.state, .pickerPresented(.library))
    }

    private func makeModel(container: AppContainer) -> CoachModel {
        CoachModelTestFactory.makeModel(
            actionCenter: container.actionCenter,
            dailyLogReader: container.dailyLogService,
            healthActivityQuery: container.healthActivityQueryService
        )
    }

    private static func makeTestImage(size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            UIColor.systemGreen.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}

@MainActor
private extension CoachImagePickFlowController {
    func handleFailureForTests(_ error: CoachMealPhotoError, model: CoachModel) async {
        setStateForTests(.failed(error))
        model.appendMealPhotoSelectionFailure(error)
        setStateForTests(.idle)
    }
}
