//
//  CoachPhotoLibrarySelectionRaceTests.swift
//  Fitness CoachTests
//
//  Regression tests for Coach photo library picker dismiss/selection races.
//  These encode the target behavior after the race fix and should fail on the
//  pre-fix production path where selection can be silently dropped.
//

import UIKit
import XCTest
@testable import Fitness_Coach

@MainActor
final class CoachPhotoLibrarySelectionRaceTests: XCTestCase {

    // MARK: - Test 1 — dismiss before selection callback

    func testDismissBeforeSelectionCallbackShouldNotSilentlyDropSelection() async throws {
        let container = try AppContainer(inMemory: true)
        let model = CoachPhotoLibrarySelectionRaceTestSupport.makeModel(container: container)
        let image = CoachPhotoLibrarySelectionRaceTestSupport.makeTestImage()
        let flow = CoachPhotoLibrarySelectionRaceTestSupport.makeFlow(loading: image)
        let item = CoachPhotoLibrarySelectionRaceTestSupport.testPickerItem

        XCTAssertTrue(flow.beginPhotoLibraryPick(model: model))
        XCTAssertEqual(flow.state, .pickerPresented(.library))

        // PhotosPicker dismisses before `photoPickerItem` onChange (librarySelectionReceived still false).
        flow.handlePhotoLibraryPickerDismissed()
        XCTAssertEqual(flow.state, .idle, "Precondition: dismiss wins the race and resets flow state")

        await CoachPhotoLibrarySelectionRaceTestSupport.simulateCoachViewLibrarySelectionCallback(
            flow: flow,
            item: item,
            model: model
        )

        XCTAssertEqual(
            flow.state,
            .processingImage(.library),
            "Selection with a valid item must claim the flow before async loading"
        )
        XCTAssertTrue(
            model.inputState.pendingImage?.isProcessing == true,
            "Model must begin pending image processing when a library item is selected"
        )
    }

    // MARK: - Test 2 — selection started, dismiss during early window

    func testDismissDuringEarlySelectionWindowShouldNotResetInFlightSelection() async throws {
        let container = try AppContainer(inMemory: true)
        let model = CoachPhotoLibrarySelectionRaceTestSupport.makeModel(container: container)
        let image = CoachPhotoLibrarySelectionRaceTestSupport.makeTestImage()
        let flow = CoachPhotoLibrarySelectionRaceTestSupport.makeFlow(loading: image)
        let item = CoachPhotoLibrarySelectionRaceTestSupport.testPickerItem

        XCTAssertTrue(flow.beginPhotoLibraryPick(model: model))
        flow.markLibrarySelectionReceived()

        flow.debugPhotoLibrarySelectionEntryHook = {
            flow.handlePhotoLibraryPickerDismissed()
        }

        await flow.handlePhotoLibrarySelection(item, model: model)
        flow.debugPhotoLibrarySelectionEntryHook = nil

        XCTAssertEqual(
            flow.state,
            .processingImage(.library),
            "Dismiss during the early selection window must not reset an in-flight library pick"
        )
        XCTAssertTrue(
            model.inputState.pendingImage?.isProcessing == true || model.inputState.pendingImage?.isReady == true,
            "In-flight selection must continue into processing or complete staging"
        )
    }

    // MARK: - Test 3 — cancel without selection

    func testCancelWithoutSelectionReturnsIdleWithCleanComposer() throws {
        let container = try AppContainer(inMemory: true)
        let model = CoachPhotoLibrarySelectionRaceTestSupport.makeModel(container: container)
        let flow = CoachImagePickFlowController()

        XCTAssertTrue(flow.beginPhotoLibraryPick(model: model))
        flow.handlePhotoLibraryPickerDismissed()

        XCTAssertEqual(flow.state, .idle)
        XCTAssertFalse(flow.isPhotoPickerPresented)
        XCTAssertTrue(flow.allowsAttachmentPick)
        XCTAssertNil(model.inputState.pendingImage)
        XCTAssertNil(model.inputState.imageError)
        XCTAssertFalse(model.inputState.isImageProcessing)
    }

    // MARK: - Test 4 — blocked pick while busy

    func testBlockedChoosePhotoWhileBusyReturnsFalseWithoutCorruption() async throws {
        let container = try AppContainer(inMemory: true)
        let model = CoachPhotoLibrarySelectionRaceTestSupport.makeModel(container: container)
        let flow = CoachImagePickFlowController()

        flow.setStateForTests(.processingImage(.library))
        XCTAssertFalse(flow.beginPhotoLibraryPick(model: model))
        XCTAssertEqual(flow.state, .processingImage(.library))
        XCTAssertFalse(flow.allowsAttachmentPick)

        await flow.beginCameraPick(model: model)
        XCTAssertEqual(flow.state, .processingImage(.library), "Camera pick must not corrupt library processing state")
        XCTAssertNil(model.inputState.pendingImage)
        XCTAssertNil(model.inputState.imageError)
    }

    // MARK: - Test 5 — camera regression (library race work must not break camera)

    func testCameraCaptureStillStagesReadyPendingImageAfterLibraryRaceWork() async throws {
        let container = try AppContainer(inMemory: true)
        let model = CoachPhotoLibrarySelectionRaceTestSupport.makeModel(container: container)
        let flow = CoachImagePickFlowController()
        let image = CoachPhotoLibrarySelectionRaceTestSupport.makeTestImage()

        flow.setStateForTests(.pickerPresented(.camera))
        await flow.handleCameraResult(.success(image), model: model)

        XCTAssertEqual(flow.state, .idle)
        XCTAssertEqual(model.inputState.pendingImage?.source, .camera)
        XCTAssertEqual(model.inputState.pendingImage?.status, .ready)
    }

    func testCameraDismissAfterDeliveredResultStillDoesNotDropCapture() async throws {
        let container = try AppContainer(inMemory: true)
        let model = CoachPhotoLibrarySelectionRaceTestSupport.makeModel(container: container)
        let flow = CoachImagePickFlowController()
        let image = CoachPhotoLibrarySelectionRaceTestSupport.makeTestImage()

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
}

@MainActor
private extension CoachImagePickFlowController {
    func setStateForTests(_ newState: CoachImagePickFlowState) {
        state = newState
    }
}
