//
//  CoachImagePickFlowRetryTests.swift
//  Fitness CoachTests
//
//  Composer retry for failed meal-photo preparation.
//

import UIKit
import XCTest
@testable import Fitness_Coach

@MainActor
final class CoachImagePickFlowRetryTests: XCTestCase {

    func testPreparationFailureSurfacesComposerErrorWithoutChatBubble() async throws {
        let container = try AppContainer(inMemory: true)
        let model = makeModel(container: container)
        let flow = CoachImagePickFlowController()
        let image = Self.makeTestImage(size: CGSize(width: 800, height: 600))

        flow.setStateForTests(.pickerPresented(.camera))
        await flow.simulateProcessingFailure(.encodingFailed, model: model)

        XCTAssertEqual(model.inputState.imageError, .encodingFailed)
        XCTAssertTrue(model.inputState.imageErrorSupportsRetry)
        XCTAssertTrue(model.messages.isEmpty)
    }

    func testRetryReprocessesStoredOriginalImage() async throws {
        let container = try AppContainer(inMemory: true)
        let model = makeModel(container: container)
        let flow = CoachImagePickFlowController()
        let image = Self.makeTestImage(size: CGSize(width: 960, height: 720))

        flow.setStateForTests(.pickerPresented(.camera))
        model.beginPendingImageProcessing(source: .camera)
        let localReferenceID = model.storePendingImageLocalSource(image)
        model.attachPendingImageLocalReference(localReferenceID)

        await flow.simulateProcessingFailure(.encodingFailed, model: model)
        XCTAssertEqual(model.inputState.imageError, .encodingFailed)

        await flow.retryFailedImageSelection(model: model)

        XCTAssertNil(model.inputState.imageError)
        XCTAssertEqual(model.inputState.pendingImage?.status, .ready)
        XCTAssertNotNil(model.inputState.pendingImage?.thumbnail)
        XCTAssertFalse(model.inputState.pendingImage?.uploadData.isEmpty == true)
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
            UIColor.systemOrange.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}

#if DEBUG
@MainActor
private extension CoachImagePickFlowController {
    func simulateProcessingFailure(_ error: CoachMealPhotoError, model: CoachModel) async {
        setStateForTests(.processingImage(.camera))
        model.failPendingImageProcessing(error)
        setStateForTests(.failed(error))
        setStateForTests(.idle)
    }
}
#endif
