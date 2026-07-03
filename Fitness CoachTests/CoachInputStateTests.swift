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
        XCTAssertTrue(state.canPickImage)
    }

    func testTextOnlyCanSend() {
        var state = CoachInputState.empty
        state.updateText("log water")
        XCTAssertTrue(state.canSend)
        XCTAssertTrue(state.canPickImage)
    }

    func testAttachmentOnlyCanSend() throws {
        var state = CoachInputState.empty
        let jpeg = try makeTestJPEG()
        XCTAssertTrue(stageTestImage(&state, jpeg: jpeg, source: .library))
        XCTAssertTrue(state.canSend)
        XCTAssertFalse(state.canPickImage)
    }

    func testSecondImageRequiresRemoveFirst() throws {
        var state = CoachInputState.empty
        let first = try makeTestJPEG()
        let second = try makeTestJPEG()

        XCTAssertTrue(stageTestImage(&state, jpeg: first, source: .camera))
        let firstAttachmentID = try XCTUnwrap(state.attachment?.id)

        XCTAssertFalse(stageTestImage(&state, jpeg: second, source: .library))
        XCTAssertEqual(state.error, .attachmentAlreadyPresent)
        XCTAssertEqual(state.attachment?.id, firstAttachmentID)
        XCTAssertEqual(state.attachment?.source, .camera)
    }

    func testRemoveAttachmentClearsErrorAndAllowsNewPick() throws {
        var state = CoachInputState.empty
        let first = try makeTestJPEG()
        let second = try makeTestJPEG()

        XCTAssertTrue(stageTestImage(&state, jpeg: first, source: .library))
        _ = stageTestImage(&state, jpeg: second, source: .camera)
        XCTAssertEqual(state.error, .attachmentAlreadyPresent)

        state.removeAttachment()
        XCTAssertNil(state.error)
        XCTAssertTrue(state.canPickImage)
        XCTAssertTrue(stageTestImage(&state, jpeg: second, source: .camera))
        XCTAssertEqual(state.attachment?.source, .camera)
    }

    func testTakeSendSnapshotFreezesAndClearsComposer() throws {
        var state = CoachInputState.empty
        let jpeg = try makeTestJPEG()
        state.updateText("  Lunch bowl  ")
        XCTAssertTrue(stageTestImage(&state, jpeg: jpeg, source: .library))

        let snapshot = state.takeSendSnapshot()
        let frozen = try XCTUnwrap(snapshot)

        XCTAssertEqual(frozen.text, "  Lunch bowl  ")
        XCTAssertEqual(frozen.trimmedText, "Lunch bowl")
        XCTAssertEqual(frozen.attachment?.imageData, jpeg)
        XCTAssertEqual(frozen.attachment?.source, .library)
        XCTAssertTrue(state.text.isEmpty)
        XCTAssertNil(state.attachment)
        XCTAssertNil(state.error)
        XCTAssertFalse(state.canSend)
    }

    func testRestoreSnapshotReturnsComposerToPreSendState() throws {
        var state = CoachInputState.empty
        let jpeg = try makeTestJPEG()
        state.updateText("  Lunch bowl  ")
        XCTAssertTrue(stageTestImage(&state, jpeg: jpeg, source: .library))

        let snapshot = try XCTUnwrap(state.takeSendSnapshot())
        state.restore(from: snapshot)

        XCTAssertEqual(state.text, "  Lunch bowl  ")
        XCTAssertEqual(state.attachment?.imageData, jpeg)
        XCTAssertEqual(state.attachment?.source, .library)
        XCTAssertTrue(state.canSend)
    }

    func testSendSnapshotPayloadVariants() throws {
        let jpeg = try makeTestJPEG()

        var imageOnly = CoachInputState.empty
        _ = stageTestImage(&imageOnly, jpeg: jpeg, source: .camera)
        if case .imageOnly(let data) = imageOnly.takeSendSnapshot()?.sendPayload {
            XCTAssertEqual(data, jpeg)
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
            XCTAssertEqual(data, jpeg)
        } else {
            XCTFail("Expected text+image payload")
        }
    }

    func testSendingDisablesSendAndPick() throws {
        var state = CoachInputState.empty
        state.updateText("hello")
        state.setSending(true)

        XCTAssertFalse(state.canSend)
        XCTAssertFalse(state.canPickImage)
        XCTAssertNil(state.takeSendSnapshot())
    }

    func testRemoveAttachmentDisablesSendUntilTextOrImageReturns() throws {
        var state = CoachInputState.empty
        let jpeg = try makeTestJPEG()
        XCTAssertTrue(stageTestImage(&state, jpeg: jpeg, source: .library))
        XCTAssertTrue(state.canSend)

        state.removeAttachment()
        XCTAssertFalse(state.canSend)

        state.updateText("caption")
        XCTAssertTrue(state.canSend)
        XCTAssertFalse(state.canPickImage)
    }

    func testAttachmentBuildsThumbnail() async throws {
        let jpeg = try makeTestJPEG()
        let attachment = try XCTUnwrap(
            await CoachInputAttachment.make(jpegData: jpeg, source: .library)
        )

        XCTAssertEqual(attachment.kind, .image)
        XCTAssertFalse(attachment.thumbnail.isEmpty)
        XCTAssertLessThan(attachment.thumbnail.count, jpeg.count)
        XCTAssertNotNil(attachment.uiImage)
        XCTAssertNotNil(attachment.thumbnailImage)
    }

    private func stageTestImage(
        _ state: inout CoachInputState,
        jpeg: Data,
        source: CoachInputAttachmentSource
    ) -> Bool {
        let thumbnail = CoachMealPhotoPipeline.makeThumbnailJPEGSync(from: jpeg) ?? jpeg
        return state.stagePreparedImage(jpegData: jpeg, thumbnail: thumbnail, source: source)
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
