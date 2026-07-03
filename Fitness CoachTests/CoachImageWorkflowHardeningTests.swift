//
//  CoachImageWorkflowHardeningTests.swift
//  Fitness CoachTests
//
//  Regression coverage for Coach image workflow hardening.
//

import UIKit
import XCTest
@testable import Fitness_Coach

@MainActor
final class CoachImageWorkflowHardeningTests: XCTestCase {

    func testDoubleTapSendTransmitsOnlyOnce() async throws {
        let aiService = HoldablePhotoAIService()
        let model = try CoachImageWorkflowTestSupport.makeCoach(aiService: aiService).0
        let jpeg = CoachImageWorkflowTestSupport.makeTestJPEG()

        XCTAssertTrue(await CoachImageWorkflowTestSupport.stageTestMealPhoto(on: model, jpeg: jpeg, source: .library))

        async let firstSend = model.sendCurrentMessage()
        async let secondSend = model.sendCurrentMessage()
        await firstSend
        await secondSend

        XCTAssertEqual(aiService.analyzeMealImageCallCount, 1)
    }

    func testPhotoAuthFailureShowsSessionRetryBanner() async throws {
        let aiService = WorkflowCapturingPhotoAIService()
        aiService.injectedError = AIServiceError.authenticationFailed
        let model = try CoachImageWorkflowTestSupport.makeCoach(aiService: aiService).0

        XCTAssertTrue(await CoachImageWorkflowTestSupport.stageTestMealPhoto(
            on: model,
            jpeg: CoachImageWorkflowTestSupport.makeTestJPEG(),
            source: .library
        ))
        await model.sendCurrentMessage()

        XCTAssertTrue(model.showsAuthRetry)
        XCTAssertNotNil(model.errorTitle)
        XCTAssertNotNil(model.errorMessage)
        XCTAssertNil(model.pendingConfirmation)
    }

    func testTranscriptReloadPreservesRenderableMealPhotoMessages() throws {
        let store = CoachInMemoryChatTranscriptStore()
        let attachment = try makeTranscriptAttachment()
        let userMessage = ChatMessage.userMealPhoto(caption: "Lunch", attachment: attachment)
        let failure = ChatMessage.assistantPhotoAnalysisFailure(
            text: "I couldn't analyze that photo right now.",
            sessionID: UUID(),
            relatedUserMessageID: userMessage.id
        )

        store.saveMessages([userMessage, failure])
        let reloaded = store.loadMessages()

        XCTAssertEqual(reloaded.count, 2)
        guard case .userMealPhoto(let renderedAttachment, let caption) =
            CoachMessagePresenter.presentation(for: reloaded[0]) else {
            return XCTFail("Expected user meal photo presentation after reload")
        }
        XCTAssertEqual(renderedAttachment.imageJPEG, attachment.imageJPEG)
        XCTAssertEqual(caption, "Lunch")

        guard case .assistantPhotoAnalysis(_, let relatedID, let kind) =
            CoachMessagePresenter.presentation(for: reloaded[1]) else {
            return XCTFail("Expected assistant photo analysis presentation after reload")
        }
        XCTAssertEqual(relatedID, userMessage.id)
        XCTAssertEqual(kind, .failure)
    }

    func testCameraPermissionDeniedMapsToUserFacingCopy() {
        let message = CoachResponseBuilder.mealPhotoError(.cameraPermissionDenied)
        XCTAssertTrue(message.contains("Camera access"))
        XCTAssertTrue(message.contains("Settings"))
    }

    func testPipelinePassesThroughGatewaySizedJPEGWithoutGrowth() throws {
        let jpeg = try makeSmallJPEG()
        guard let image = UIImage(data: jpeg),
              case .success(let processed) = CoachImagePipeline.process(image: image) else {
            return XCTFail("Expected pipeline output")
        }
        XCTAssertTrue(AIGatewayPayloadLimits.fitsImagePayload(processed.uploadData))
        XCTAssertLessThanOrEqual(processed.uploadData.count, CoachImageUploadConfig.default.maxUploadBytes)
    }

    private func makeTranscriptAttachment() throws -> ChatMessageImageAttachment {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 32, height: 32))
        let image = renderer.image { context in
            UIColor.systemGreen.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 32, height: 32))
        }
        let data = try XCTUnwrap(image.jpegData(compressionQuality: 0.85))
        return try XCTUnwrap(ChatMessageImageAttachment.fromJPEG(data, source: .library))
    }

    private func makeSmallJPEG() throws -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 16, height: 16))
        let image = renderer.image { context in
            UIColor.systemOrange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 16, height: 16))
        }
        return try XCTUnwrap(image.jpegData(compressionQuality: 0.7))
    }
}
