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

        // Step 1: Open Coach.
        XCTAssertNotNil(model)

        // Step 2: Tap plus.
        XCTAssertTrue(model.requestPhotoPick())

        // Steps 3–4: Choose library, select image.
        await model.handleMealPhotoSelection(.success(libraryJPEG), source: .library)

        // Step 5: Confirm image appears in input bar.
        XCTAssertNotNil(model.inputState.pendingImage)
        XCTAssertEqual(model.inputState.pendingImage?.source, .library)

        // Steps 6–7: Remove image, confirm composer clears.
        model.removeStagedMealPhoto()
        XCTAssertNil(model.inputState.pendingImage)
        XCTAssertFalse(model.inputState.canSend)

        // Step 8: Add another image.
        await model.handleMealPhotoSelection(.success(secondJPEG), source: .library)
        XCTAssertNotNil(model.inputState.pendingImage)

        // Steps 9–12: Send without text; bubble, analysis, draft on success only.
        await model.sendCurrentMessage()
        let imageOnlyUser = try XCTUnwrap(model.messages.first { $0.role == .user })
        XCTAssertNotNil(imageOnlyUser.mealPhotoJPEG)
        XCTAssertEqual(aiService.analyzeMealImageCallCount, 1)
        XCTAssertNotNil(model.pendingConfirmation)
        guard case .food(let firstDraft) = model.pendingConfirmation else {
            return XCTFail("Expected meal draft card after successful analysis")
        }
        XCTAssertEqual(firstDraft.mealDraft.displayName, "Photo meal")

        // Step 13: Text + image.
        aiService.resetCounters()
        model.inputText = "Lunch bowl"
        await model.handleMealPhotoSelection(.success(libraryJPEG), source: .library)
        await model.sendCurrentMessage()
        let captioned = try XCTUnwrap(model.messages.last { $0.role == .user })
        XCTAssertEqual(captioned.text, "Lunch bowl")
        XCTAssertNotNil(captioned.mealPhotoJPEG)
        XCTAssertEqual(aiService.analyzeMealImageCallCount, 1)

        // Step 14: Camera source.
        aiService.resetCounters()
        await model.handleMealPhotoSelection(.success(cameraJPEG), source: .camera)
        await model.sendCurrentMessage()
        XCTAssertEqual(model.messages.last { $0.role == .user }?.imageAttachment?.source, .camera)
        XCTAssertEqual(aiService.analyzeMealImageCallCount, 1)

        // Step 15: Cancel camera.
        let messageCountBeforeCancel = model.messages.count
        await model.handleMealPhotoSelection(.failure(.userCancelled), source: .camera)
        XCTAssertEqual(model.messages.count, messageCountBeforeCancel)

        // Step 16: Cancel library.
        await model.handleMealPhotoSelection(.failure(.userCancelled), source: .library)
        XCTAssertEqual(model.messages.count, messageCountBeforeCancel)

        // Step 17: Deny permissions.
        await model.handleMealPhotoSelection(.failure(.cameraPermissionDenied), source: .camera)
        XCTAssertTrue(model.messages.last?.text.contains("Camera access") == true)

        // Steps 18–22: Offline send + retry on a clean model.
        let offlineService = WorkflowCapturingPhotoAIService()
        offlineService.injectedError = AIServiceError.networkUnavailable
        let (offlineModel, _) = try CoachImageWorkflowTestSupport.makeCoach(aiService: offlineService)
        let offlineJPEG = CoachImageWorkflowTestSupport.makeTestJPEG(color: .systemRed)

        await offlineModel.handleMealPhotoSelection(.success(offlineJPEG), source: .library)
        await offlineModel.sendCurrentMessage()

        XCTAssertNil(offlineModel.pendingConfirmation)
        XCTAssertTrue(offlineModel.messages.contains { $0.photoAnalysisLink?.kind == .failure })

        let offlineUserID = try XCTUnwrap(offlineModel.messages.first { $0.role == .user }?.id)
        let originalPayload = try XCTUnwrap(offlineService.receivedImagePayloads.first)

        offlineService.injectedError = nil
        await offlineModel.retryMealPhotoAnalysis(for: offlineUserID)

        XCTAssertEqual(offlineService.analyzeMealImageCallCount, 2)
        XCTAssertEqual(offlineService.receivedImagePayloads.last, originalPayload)
        XCTAssertNotNil(offlineModel.pendingConfirmation)
        XCTAssertFalse(offlineModel.messages.contains { $0.photoAnalysisLink?.kind == .failure })
        XCTAssertEqual(
            offlineModel.messages.filter { $0.photoAnalysisLink?.kind == .result }.count,
            1
        )
        guard case .food(let retryDraft) = offlineModel.pendingConfirmation else {
            return XCTFail("Expected single draft card after successful retry")
        }
        XCTAssertEqual(retryDraft.mealDraft.displayName, "Photo meal")
    }
}

private extension WorkflowCapturingPhotoAIService {
    func resetCounters() {
        analyzeMealImageCallCount = 0
        receivedImagePayloads = []
        receivedPrompts = []
        receivedClarifications = []
        injectedError = nil
    }
}
