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
        XCTAssertTrue(state.stageImage(jpegData: jpeg, source: .library))
        XCTAssertTrue(state.canSend)
        XCTAssertFalse(state.canPickImage)
    }

    func testSecondImageRequiresRemoveFirst() throws {
        var state = CoachInputState.empty
        let first = try makeTestJPEG()
        let second = try makeTestJPEG()

        XCTAssertTrue(state.stageImage(jpegData: first, source: .camera))
        let firstAttachmentID = try XCTUnwrap(state.attachment?.id)

        XCTAssertFalse(state.stageImage(jpegData: second, source: .library))
        XCTAssertEqual(state.error, .attachmentAlreadyPresent)
        XCTAssertEqual(state.attachment?.id, firstAttachmentID)
        XCTAssertEqual(state.attachment?.source, .camera)
    }

    func testRemoveAttachmentClearsErrorAndAllowsNewPick() throws {
        var state = CoachInputState.empty
        let first = try makeTestJPEG()
        let second = try makeTestJPEG()

        XCTAssertTrue(state.stageImage(jpegData: first, source: .library))
        _ = state.stageImage(jpegData: second, source: .camera)
        XCTAssertEqual(state.error, .attachmentAlreadyPresent)

        state.removeAttachment()
        XCTAssertNil(state.error)
        XCTAssertTrue(state.canPickImage)
        XCTAssertTrue(state.stageImage(jpegData: second, source: .camera))
        XCTAssertEqual(state.attachment?.source, .camera)
    }

    func testTakeSendSnapshotFreezesAndClearsComposer() throws {
        var state = CoachInputState.empty
        let jpeg = try makeTestJPEG()
        state.updateText("  Lunch bowl  ")
        XCTAssertTrue(state.stageImage(jpegData: jpeg, source: .library))

        let snapshot = state.takeSendSnapshot()
        let frozen = try XCTUnwrap(snapshot)

        XCTAssertEqual(frozen.trimmedText, "Lunch bowl")
        XCTAssertEqual(frozen.attachment?.imageData, jpeg)
        XCTAssertEqual(frozen.attachment?.source, .library)
        XCTAssertTrue(state.text.isEmpty)
        XCTAssertNil(state.attachment)
        XCTAssertNil(state.error)
        XCTAssertFalse(state.canSend)
    }

    func testSendSnapshotPayloadVariants() throws {
        let jpeg = try makeTestJPEG()

        var imageOnly = CoachInputState.empty
        _ = imageOnly.stageImage(jpegData: jpeg, source: .camera)
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
        _ = combined.stageImage(jpegData: jpeg, source: .library)
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

    func testAttachmentBuildsThumbnail() throws {
        let jpeg = try makeTestJPEG()
        let attachment = try XCTUnwrap(
            CoachInputAttachment.make(jpegData: jpeg, source: .library)
        )

        XCTAssertEqual(attachment.kind, .image)
        XCTAssertFalse(attachment.thumbnail.isEmpty)
        XCTAssertLessThan(attachment.thumbnail.count, jpeg.count)
        XCTAssertNotNil(attachment.uiImage)
        XCTAssertNotNil(attachment.thumbnailImage)
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
