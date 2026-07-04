//
//  CoachInputStateTests.swift
//  Fitness CoachTests
//
//  Forma — Unit tests for Coach composer input state.
//

import UIKit
import XCTest
@testable import Fitness_Coach

final class CoachInputStateTests: XCTestCase {

    func testEmptyStateCannotSendOrPick() {
        var state = CoachInputState.empty
        XCTAssertFalse(state.canSend)
        XCTAssertTrue(state.canStartImageSelection)
    }

    func testTextOnlyCanSend() {
        var state = CoachInputState.empty
        state.updateText("log water")
        XCTAssertTrue(state.canSend)
        XCTAssertTrue(state.canStartImageSelection)
    }

    func testReadyPendingImageOnlyCanSend() throws {
        var state = CoachInputState.empty
        let jpeg = try makeTestJPEG()
        XCTAssertTrue(stageTestImage(&state, jpeg: jpeg, source: .library))
        XCTAssertTrue(state.canSend)
        XCTAssertTrue(state.canStartImageSelection)
    }

    func testProcessingDisablesSendAndNewSelection() throws {
        var state = CoachInputState.empty
        let jpeg = try makeTestJPEG()
        XCTAssertTrue(stageTestImage(&state, jpeg: jpeg, source: .library))
        state.beginProcessingNewSelection(source: .camera)

        XCTAssertFalse(state.canSend)
        XCTAssertFalse(state.canStartImageSelection)
        XCTAssertTrue(state.isImageProcessing)
    }

    func testReplacePendingImageOnlyAfterProcessingSucceeds() throws {
        var state = CoachInputState.empty
        let first = try makeTestJPEG()
        let second = try makeTestJPEG()
        XCTAssertTrue(stageTestImage(&state, jpeg: first, source: .camera))
        let firstID = try XCTUnwrap(state.pendingImage?.id)
        let firstUpload = try XCTUnwrap(state.pendingImage?.uploadData)

        state.beginProcessingNewSelection(source: .library)
        XCTAssertEqual(state.pendingImage?.id, firstID)
        XCTAssertEqual(state.pendingImage?.uploadData, firstUpload)

        guard let secondImage = UIImage(data: second),
              case .success(let processed) = CoachImagePipeline.process(image: secondImage) else {
            return XCTFail("Expected processed second image")
        }
        XCTAssertTrue(state.applyProcessedImage(
            processed,
            source: .library,
            originalEstimatedBytes: second.count
        ))
        XCTAssertNotEqual(state.pendingImage?.id, firstID)
        XCTAssertEqual(state.pendingImage?.uploadData, processed.uploadData)
    }

    func testFailedProcessingPreservesReadyPendingImage() throws {
        var state = CoachInputState.empty
        let jpeg = try makeTestJPEG()
        XCTAssertTrue(stageTestImage(&state, jpeg: jpeg, source: .library))
        let firstID = try XCTUnwrap(state.pendingImage?.id)

        state.beginProcessingNewSelection(source: .camera)
        state.failImageProcessing(.encodingFailed)

        XCTAssertEqual(state.pendingImage?.id, firstID)
        XCTAssertEqual(state.pendingImage?.status, .ready)
        XCTAssertEqual(state.imageError, .encodingFailed)
    }

    func testClearPendingImageClearsErrorAndAllowsNewPick() throws {
        var state = CoachInputState.empty
        let first = try makeTestJPEG()
        let second = try makeTestJPEG()

        XCTAssertTrue(stageTestImage(&state, jpeg: first, source: .library))
        state.failImageProcessing(.loadFailed)
        state.clearPendingImage()

        XCTAssertNil(state.pendingImage)
        XCTAssertNil(state.imageError)
        XCTAssertTrue(state.canStartImageSelection)
        XCTAssertTrue(stageTestImage(&state, jpeg: second, source: .camera))
        XCTAssertEqual(state.pendingImage?.source, .camera)
    }

    func testTakeSendSnapshotConsumesReadyPendingImage() throws {
        var state = CoachInputState.empty
        let jpeg = try makeTestJPEG()
        state.updateText("  Lunch bowl  ")
        let uploadData = try processedUploadData(from: jpeg)
        XCTAssertTrue(stageTestImage(&state, jpeg: jpeg, source: .library))

        let snapshot = state.takeSendSnapshot()
        let frozen = try XCTUnwrap(snapshot)

        XCTAssertEqual(frozen.text, "  Lunch bowl  ")
        XCTAssertEqual(frozen.trimmedText, "Lunch bowl")
        XCTAssertEqual(frozen.pendingImage?.uploadData, uploadData)
        XCTAssertEqual(frozen.pendingImage?.source, .library)
        XCTAssertTrue(state.text.isEmpty)
        XCTAssertNil(state.pendingImage)
        XCTAssertNil(state.imageError)
        XCTAssertFalse(state.canSend)
    }

    func testRestoreSnapshotReturnsComposerToPreSendState() throws {
        var state = CoachInputState.empty
        let jpeg = try makeTestJPEG()
        state.updateText("  Lunch bowl  ")
        let uploadData = try processedUploadData(from: jpeg)
        XCTAssertTrue(stageTestImage(&state, jpeg: jpeg, source: .library))

        let snapshot = try XCTUnwrap(state.takeSendSnapshot())
        state.restore(from: snapshot)

        XCTAssertEqual(state.text, "  Lunch bowl  ")
        XCTAssertEqual(state.pendingImage?.uploadData, uploadData)
        XCTAssertEqual(state.pendingImage?.source, .library)
        XCTAssertTrue(state.canSend)
    }

    func testSendSnapshotPayloadVariants() throws {
        let jpeg = try makeTestJPEG()
        let uploadData = try processedUploadData(from: jpeg)

        var imageOnly = CoachInputState.empty
        _ = stageTestImage(&imageOnly, jpeg: jpeg, source: .camera)
        if case .imageOnly(let data) = imageOnly.takeSendSnapshot()?.sendPayload {
            XCTAssertEqual(data, uploadData)
        } else {
            XCTFail("Expected image-only payload")
        }

        var textOnly = CoachInputState.empty
        textOnly.updateText("hello")
        if case .textOnly(let text) = textOnly.takeSendSnapshot()?.sendPayload {
            XCTAssertEqual(text, "hello")
        } else {
            XCTFail("Expected text-only payload")
        }

        var combined = CoachInputState.empty
        combined.updateText("caption")
        _ = stageTestImage(&combined, jpeg: jpeg, source: .library)
        if case .textAndImage(let text, let data) = combined.takeSendSnapshot()?.sendPayload {
            XCTAssertEqual(text, "caption")
            XCTAssertEqual(data, uploadData)
        } else {
            XCTFail("Expected text+image payload")
        }
    }

    func testSendingDisablesSendAndPick() throws {
        var state = CoachInputState.empty
        state.updateText("hello")
        state.setSending(true)

        XCTAssertFalse(state.canSend)
        XCTAssertFalse(state.canStartImageSelection)
        XCTAssertNil(state.takeSendSnapshot())
    }

    func testRemovePendingImageDisablesSendUntilTextOrImageReturns() throws {
        var state = CoachInputState.empty
        let jpeg = try makeTestJPEG()
        XCTAssertTrue(stageTestImage(&state, jpeg: jpeg, source: .library))
        XCTAssertTrue(state.canSend)

        state.clearPendingImage()
        XCTAssertFalse(state.canSend)

        state.updateText("caption")
        XCTAssertTrue(state.canSend)
        XCTAssertTrue(state.canStartImageSelection)
    }

    private func stageTestImage(
        _ state: inout CoachInputState,
        jpeg: Data,
        source: CoachInputAttachmentSource
    ) -> Bool {
        guard let image = UIImage(data: jpeg),
              case .success(let processed) = CoachImagePipeline.process(image: image) else {
            return false
        }
        return state.applyProcessedImage(
            processed,
            source: source,
            originalEstimatedBytes: jpeg.count
        )
    }

    private func processedUploadData(from jpeg: Data) throws -> Data {
        guard let image = UIImage(data: jpeg),
              case .success(let processed) = CoachImagePipeline.process(image: image) else {
            throw XCTSkip("Expected processed upload data")
        }
        return processed.uploadData
    }

    private func makeTestJPEG() throws -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 48))
        let image = renderer.image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 64, height: 48))
        }
        return try XCTUnwrap(image.jpegData(compressionQuality: 0.85))
    }
}
