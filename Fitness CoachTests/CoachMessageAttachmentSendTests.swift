//
//  CoachMessageAttachmentSendTests.swift
//  Fitness CoachTests
//
//  Coach send flow with staged pending images.
//
//  Production path: `CoachImagePickFlowController` stages into
//  `CoachInputState.pendingImage` (`CoachPendingImageState`); send reads
//  `CoachInputSendSnapshot` upload bytes — not legacy `importAttachment`.
//

import UIKit
import XCTest
@testable import Fitness_Coach

@MainActor
final class CoachMessageAttachmentSendTests: XCTestCase {

    func testSendImageOnlyClearsPendingImageAndAttachesToUserMessage() async throws {
        let aiService = WorkflowCapturingPhotoAIService()
        let model = try CoachImageWorkflowTestSupport.makeCoach(aiService: aiService).0
        let jpeg = CoachImageWorkflowTestSupport.makeTestJPEG()

        XCTAssertTrue(await CoachImageWorkflowTestSupport.stageTestMealPhoto(
            on: model,
            jpeg: jpeg,
            source: .library
        ))
        await model.sendCurrentMessage()

        let userMessage = try XCTUnwrap(model.messages.last(where: { $0.role == .user }))
        XCTAssertTrue(userMessage.hasAttachedImage)
        XCTAssertTrue(userMessage.text.isEmpty)
        XCTAssertNil(model.inputState.pendingImage)
        XCTAssertTrue(model.inputText.isEmpty)
        XCTAssertEqual(aiService.analyzeMealImageCallCount, 1)
        XCTAssertEqual(aiService.receivedImagePayloads.last, model.messages.last?.mealPhotoJPEG)
    }

    func testSendTextAndImageUsesCaptionInUserMessage() async throws {
        let aiService = WorkflowCapturingPhotoAIService()
        let model = try CoachImageWorkflowTestSupport.makeCoach(aiService: aiService).0
        let jpeg = CoachImageWorkflowTestSupport.makeTestJPEG()

        model.inputText = "Lunch"
        XCTAssertTrue(await CoachImageWorkflowTestSupport.stageTestMealPhoto(
            on: model,
            jpeg: jpeg,
            source: .camera
        ))
        await model.sendCurrentMessage()

        let userMessage = try XCTUnwrap(model.messages.last(where: { $0.role == .user }))
        XCTAssertEqual(userMessage.text, "Lunch")
        XCTAssertTrue(userMessage.hasAttachedImage)
        XCTAssertNil(model.inputState.pendingImage)
        XCTAssertEqual(aiService.analyzeMealImageCallCount, 1)
    }

    func testSendFailureKeepsUserMessageWithAttachment() async throws {
        let aiService = WorkflowCapturingPhotoAIService()
        aiService.injectedError = AIServiceError.backendUnavailable
        let model = try CoachImageWorkflowTestSupport.makeCoach(aiService: aiService).0
        let jpeg = CoachImageWorkflowTestSupport.makeTestJPEG()

        XCTAssertTrue(await CoachImageWorkflowTestSupport.stageTestMealPhoto(
            on: model,
            jpeg: jpeg,
            source: .library
        ))
        await model.sendCurrentMessage()

        let userMessages = model.messages.filter { $0.role == .user }
        XCTAssertEqual(userMessages.count, 1)
        XCTAssertTrue(userMessages[0].hasAttachedImage)
        XCTAssertEqual(model.messages.last?.role, .assistant)
        XCTAssertNil(model.inputState.pendingImage)
    }

    func testChatMessageHasAttachedImageRequiresNonEmptyBytes() {
        let message = ChatMessage(
            id: UUID(),
            role: .user,
            text: "Meal photo",
            createdAt: Date(),
            relatedDailyLogId: nil,
            relatedEntryId: nil,
            attachedImageJPEGData: Data()
        )

        XCTAssertFalse(message.hasAttachedImage)
    }
}
