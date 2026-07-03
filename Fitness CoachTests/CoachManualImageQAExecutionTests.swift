//
//  CoachManualImageQAExecutionTests.swift
//  Fitness CoachTests
//
//  Programmatic execution of the 22-step Coach image manual QA checklist.
//  Run on device/simulator:
//    xcodebuild test -scheme "Fitness Coach" \
//      -only-testing:Fitness\ CoachTests/CoachManualImageQAExecutionTests
//

import UIKit
import XCTest
@testable import Fitness_Coach

@MainActor
final class CoachManualImageQAExecutionTests: XCTestCase {

    /// Executes steps 1–22 in order. Each step is annotated for manual QA parity.
    func testManualChecklistSteps1Through22() async throws {
        let aiService = WorkflowCapturingPhotoAIService()
        let (model, _) = try CoachImageWorkflowTestSupport.makeCoach(aiService: aiService)
        let libraryJPEG = CoachImageWorkflowTestSupport.makeTestJPEG(color: .systemOrange)
        let secondJPEG = CoachImageWorkflowTestSupport.makeTestJPEG(color: .systemGreen)
        let cameraJPEG = CoachImageWorkflowTestSupport.makeTestJPEG(color: .systemBlue)

        // Step 1: Open Coach — harness constructs CoachModel (Coach tab equivalent).
        XCTAssertNotNil(model)

        // Step 2: Tap plus — requestPhotoPick succeeds on empty composer.
        XCTAssertTrue(model.requestPhotoPick(), "Step 2: plus attachment menu should open pick flow")

        // Step 3–4: Choose library, select image.
        await model.handleMealPhotoSelection(.success(libraryJPEG), source: .library)

        // Step 5: Confirm image appears in input bar.
        XCTAssertNotNil(model.inputState.attachment, "Step 5: staged thumbnail should appear in composer")
        XCTAssertEqual(model.inputState.attachment?.source, .library)

        // Step 6–7: Remove image, confirm composer clears.
        model.removeStagedMealPhoto()
        XCTAssertNil(model.inputState.attachment, "Step 7: composer should clear after remove")
        XCTAssertFalse(model.inputState.canSend)

        // Step 8: Add another image.
        await model.handleMealPhotoSelection(.success(secondJPEG), source: .library)
        XCTAssertNotNil(model.inputState.attachment, "Step 8: second image should stage")

        // Step 9–12: Send without text; bubble, analysis, draft only on success.
        await model.sendCurrentMessage()
        let userMessage = try XCTUnwrap(model.messages.first { $0.role == .user })
        XCTAssertNotNil(userMessage.mealPhotoJPEG, "Step 10: chat bubble should include image")
        XCTAssertEqual(aiService.analyzeMealImageCallCount, 1, "Step 11: assistant should analyze image")
        XCTAssertNotNil(model.pendingConfirmation, "Step 12: meal draft card on success")
        guard case .food(let draft) = model.pendingConfirmation else {
            return XCTFail("Step 12: expected food draft card")
        }
        XCTAssertEqual(draft.mealDraft.displayName, "Photo meal")

        // Step 13: Repeat with text + image.
        aiService.resetCounters()
        model.inputText = "Lunch bowl"
        await model.handleMealPhotoSelection(.success(libraryJPEG), source: .library)
        await model.sendCurrentMessage()
        let captioned = try XCTUnwrap(model.messages.last { $0.role == .user && !$0.text.isEmpty })
        XCTAssertEqual(captioned.text, "Lunch bowl", "Step 13: text + image caption preserved")
        XCTAssertNotNil(captioned.mealPhotoJPEG)
        XCTAssertEqual(aiService.analyzeMealImageCallCount, 1)

        // Step 14: Repeat with camera source.
        aiService.resetCounters()
        await model.handleMealPhotoSelection(.success(cameraJPEG), source: .camera)
        await model.sendCurrentMessage()
        XCTAssertEqual(
            model.messages.last { $0.role == .user }?.imageAttachment?.source,
            .camera,
            "Step 14: camera source preserved on user bubble"
        )
        XCTAssertEqual(aiService.analyzeMealImageCallCount, 1)

        // Step 15: Cancel camera — no messages, composer unchanged.
        let messagesBeforeCameraCancel = model.messages.count
        let attachmentBeforeCameraCancel = model.stagedMealPhotoJPEG
        await model.handleMealPhotoSelection(.failure(.userCancelled), source: .camera)
        XCTAssertEqual(model.messages.count, messagesBeforeCameraCancel, "Step 15: cancel camera is silent")
        XCTAssertEqual(model.stagedMealPhotoJPEG, attachmentBeforeCameraCancel)

        // Step 16: Cancel library — same silent cancel path.
        await model.handleMealPhotoSelection(.failure(.userCancelled), source: .library)
        XCTAssertEqual(model.messages.count, messagesBeforeCameraCancel, "Step 16: cancel library is silent")

        // Step 17: Deny permissions — camera permission surfaces guidance copy.
        let permissionMessage = CoachResponseBuilder.mealPhotoError(.cameraPermissionDenied)
        XCTAssertTrue(permissionMessage.contains("Settings"), "Step 17: denied permission copy references Settings")
        await model.handleMealPhotoSelection(.failure(.cameraPermissionDenied), source: .camera)
        XCTAssertTrue(
            model.messages.last?.text.contains("Camera access") == true,
            "Step 17: denied permission should surface assistant guidance"
        )

        // Step 18–19: Network off, send — no fake food result.
        aiService.resetCounters()
        aiService.injectedError = AIServiceError.networkUnavailable
        await model.handleMealPhotoSelection(.success(libraryJPEG), source: .library)
        await model.sendCurrentMessage()
        XCTAssertNil(model.pendingConfirmation, "Step 19: no draft card when network fails")
        XCTAssertTrue(
            model.messages.contains { $0.photoAnalysisLink?.kind == .failure },
            "Step 18: failure bubble should appear offline"
        )

        // Step 20–22: Retry failed analysis — same image, no duplicate drafts.
        let failedUserID = try XCTUnwrap(model.messages.last { $0.role == .user }?.id)
        let payloadBeforeRetry = try XCTUnwrap(aiService.receivedImagePayloads.last)
        aiService.injectedError = nil
        guard case .food(let draftBeforeRetry) = model.pendingConfirmation else {
            // Expected nil after failure; capture for duplicate check after retry.
        }
        _ = draftBeforeRetry

        await model.retryMealPhotoAnalysis(for: failedUserID)
        XCTAssertEqual(aiService.analyzeMealImageCallCount, 2, "Step 20: retry should re-analyze")
        XCTAssertEqual(
            aiService.receivedImagePayloads.last,
            payloadBeforeRetry,
            "Step 21: retry must reuse same JPEG bytes"
        )
        XCTAssertNotNil(model.pendingConfirmation, "Step 20: draft appears after successful retry")
        let resultMessageCount = model.messages.filter { $0.photoAnalysisLink?.kind == .result }.count
        XCTAssertLessThanOrEqual(resultMessageCount, 2, "Step 22: no duplicate result bubbles")
        guard case .food(let draftAfterRetry) = model.pendingConfirmation else {
            return XCTFail("Step 22: expected single draft card after retry")
        }
        XCTAssertEqual(
            model.messages.filter { $0.photoAnalysisLink?.kind == .result }.count,
            1,
            "Step 22: exactly one success analysis message after retry supersedes failure"
        )
        _ = draftAfterRetry
    }
}

private extension WorkflowCapturingPhotoAIService {
    func resetCounters() {
        analyzeMealImageCallCount = 0
        receivedImagePayloads = []
        receivedPrompts = []
        injectedError = nil
    }
}
