//
//  CoachMessagePresenterTests.swift
//  Fitness CoachTests
//
//  Forma — Presentation mapping for Coach chat transcript messages.
//

import UIKit
import XCTest
@testable import Fitness_Coach

final class CoachMessagePresenterTests: XCTestCase {

    func testUserMealPhotoWithoutCaptionRendersImageOnlyPresentation() throws {
        let attachment = try makeAttachment()
        let message = ChatMessage.userMealPhoto(caption: nil, attachment: attachment)

        let presentation = CoachMessagePresenter.presentation(for: message)

        guard case .userMealPhoto(let renderedAttachment, let caption) = presentation else {
            return XCTFail("Expected user meal photo presentation")
        }
        XCTAssertEqual(renderedAttachment.imageJPEG, attachment.imageJPEG)
        XCTAssertNil(caption)
        XCTAssertTrue(message.text.isEmpty)
        XCTAssertNotEqual(message.text, CoachMealPhotoPipeline.userMessageLabel)
    }

    func testUserMealPhotoWithCaptionPreservesCaption() throws {
        let attachment = try makeAttachment()
        let message = ChatMessage.userMealPhoto(caption: "Lunch bowl", attachment: attachment)

        guard case .userMealPhoto(_, let caption) = CoachMessagePresenter.presentation(for: message) else {
            return XCTFail("Expected user meal photo presentation")
        }

        XCTAssertEqual(caption, "Lunch bowl")
    }

    func testAssistantPhotoAnalysisFailurePresentation() throws {
        let userID = UUID()
        let message = ChatMessage.assistantPhotoAnalysisFailure(
            text: "I couldn't analyze that photo right now.",
            relatedUserMessageID: userID
        )

        guard case .assistantPhotoAnalysis(let text, let relatedID, let isFailure) =
            CoachMessagePresenter.presentation(for: message) else {
            return XCTFail("Expected assistant photo analysis presentation")
        }

        XCTAssertTrue(text.contains("couldn't analyze"))
        XCTAssertEqual(relatedID, userID)
        XCTAssertTrue(isFailure)
        XCTAssertNotNil(message.mealPhotoAnalysisFailure)
    }

    func testAssistantPhotoAnalysisSuccessPresentation() throws {
        let userID = UUID()
        let message = ChatMessage.assistantPhotoAnalysisResult(
            text: "From your meal photo, I estimated chicken bowl:",
            relatedUserMessageID: userID
        )

        guard case .assistantPhotoAnalysis(let text, let relatedID, let isFailure) =
            CoachMessagePresenter.presentation(for: message) else {
            return XCTFail("Expected assistant photo analysis presentation")
        }

        XCTAssertTrue(text.contains("meal photo"))
        XCTAssertEqual(relatedID, userID)
        XCTAssertFalse(isFailure)
    }

    func testPlainTextUserMessageStaysTextPresentation() {
        let message = ChatMessage(role: .user, text: "log water")
        guard case .user(let text) = CoachMessagePresenter.presentation(for: message) else {
            return XCTFail("Expected text presentation")
        }
        XCTAssertEqual(text, "log water")
    }

    private func makeAttachment() throws -> ChatMessageImageAttachment {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 24, height: 24))
        let image = renderer.image { context in
            UIColor.systemOrange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 24, height: 24))
        }
        let data = try XCTUnwrap(image.jpegData(compressionQuality: 0.85))
        return try XCTUnwrap(ChatMessageImageAttachment.fromJPEG(data, source: .camera))
    }
}
