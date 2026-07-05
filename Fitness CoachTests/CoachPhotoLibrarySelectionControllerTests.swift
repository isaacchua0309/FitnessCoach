//
//  CoachPhotoLibrarySelectionControllerTests.swift
//  Fitness CoachTests
//
//  Unit tests for the library selection controller path using injected loaders.
//  No system PhotosPicker is presented.
//

import PhotosUI
import UIKit
import XCTest
@testable import Fitness_Coach

@MainActor
final class CoachPhotoLibrarySelectionControllerTests: XCTestCase {

    // MARK: - 1. Success enters processing and stages

    func testLibrarySelectionSuccessEntersProcessingAndStagesPendingImage() async throws {
        let container = try AppContainer(inMemory: true)
        let model = CoachPhotoLibrarySelectionTestSupport.makeModel(container: container)
        let image = CoachPhotoLibrarySelectionTestSupport.makeTestImage()
        let flow = CoachPhotoLibrarySelectionTestSupport.makeFlow(loading: image)
        let item = CoachPhotoLibrarySelectionTestSupport.testPickerItem

        XCTAssertEqual(flow.beginPhotoLibraryPick(model: model), .started)
        let pickID = try XCTUnwrap(flow.activeLibraryPickSessionID)

        await CoachPhotoLibrarySelectionTestSupport.simulateCoachViewLibrarySelectionCallback(
            flow: flow,
            item: item,
            model: model,
            claimedPickID: pickID
        )

        XCTAssertEqual(model.inputState.pendingImage?.status, .ready)
        XCTAssertEqual(model.inputState.pendingImage?.source, .library)
        XCTAssertTrue(model.inputState.pendingImage?.hasValidReadyAttachment == true)
        XCTAssertEqual(flow.state, .idle)
    }

    func testLibrarySelectionEntersProcessingBeforeStagingCompletes() async throws {
        let container = try AppContainer(inMemory: true)
        let model = CoachPhotoLibrarySelectionTestSupport.makeModel(container: container)
        let image = CoachPhotoLibrarySelectionTestSupport.makeTestImage()
        let fakeLoader = FakeCoachPhotoLibraryImageLoader(
            image: image,
            gateLoadAtIndex: 0
        )
        let flow = fakeLoader.makeFlow()
        let item = CoachPhotoLibrarySelectionTestSupport.testPickerItem

        XCTAssertEqual(flow.beginPhotoLibraryPick(model: model), .started)
        let pickID = try XCTUnwrap(flow.activeLibraryPickSessionID)
        flow.markLibrarySelectionReceived(claimedPickID: pickID)
        XCTAssertTrue(flow.beginPhotoLibrarySelectionHandling())
        XCTAssertEqual(flow.state, .processingImage(.library))

        let selectionTask = Task {
            await flow.handlePhotoLibrarySelection(item, model: model)
        }
        await Task.yield()
        await Task.yield()

        XCTAssertEqual(model.inputState.pendingImage?.status, .processing)
        XCTAssertEqual(model.inputState.pendingImage?.source, .library)
        XCTAssertEqual(flow.state, .processingImage(.library))

        fakeLoader.releaseGatedLoad()
        await selectionTask.value

        XCTAssertEqual(model.inputState.pendingImage?.status, .ready)
        XCTAssertEqual(flow.state, .idle)
    }

    // MARK: - 2. Dismiss before selection

    func testDismissBeforeSelectionDoesNotDropSelection() async throws {
        let container = try AppContainer(inMemory: true)
        let model = CoachPhotoLibrarySelectionTestSupport.makeModel(container: container)
        let image = CoachPhotoLibrarySelectionTestSupport.makeTestImage()
        let flow = CoachPhotoLibrarySelectionTestSupport.makeFlow(loading: image)
        let item = CoachPhotoLibrarySelectionTestSupport.testPickerItem

        XCTAssertEqual(flow.beginPhotoLibraryPick(model: model), .started)
        let pickID = try XCTUnwrap(flow.activeLibraryPickSessionID)
        flow.handlePhotoLibraryPickerDismissed()
        XCTAssertEqual(flow.state, .idle)

        await CoachPhotoLibrarySelectionTestSupport.simulateCoachViewLibrarySelectionCallback(
            flow: flow,
            item: item,
            model: model,
            claimedPickID: pickID
        )

        XCTAssertEqual(model.inputState.pendingImage?.status, .ready)
        XCTAssertEqual(model.inputState.pendingImage?.source, .library)
        XCTAssertEqual(flow.state, .idle)
    }

    // MARK: - 3. Dismiss during selection start

    func testDismissDuringSelectionStartDoesNotDropSelection() async throws {
        let container = try AppContainer(inMemory: true)
        let model = CoachPhotoLibrarySelectionTestSupport.makeModel(container: container)
        let image = CoachPhotoLibrarySelectionTestSupport.makeTestImage()
        let flow = CoachPhotoLibrarySelectionTestSupport.makeFlow(loading: image)
        let item = CoachPhotoLibrarySelectionTestSupport.testPickerItem

        XCTAssertEqual(flow.beginPhotoLibraryPick(model: model), .started)
        let pickID = try XCTUnwrap(flow.activeLibraryPickSessionID)
        flow.markLibrarySelectionReceived(claimedPickID: pickID)

        flow.debugPhotoLibrarySelectionEntryHook = {
            flow.handlePhotoLibraryPickerDismissed()
        }

        await flow.handlePhotoLibrarySelection(item, model: model)
        flow.debugPhotoLibrarySelectionEntryHook = nil

        XCTAssertEqual(model.inputState.pendingImage?.status, .ready)
        XCTAssertEqual(model.inputState.pendingImage?.source, .library)
        XCTAssertEqual(flow.state, .idle)
    }

    // MARK: - 4. Cancel without selection

    func testCancelWithoutSelectionReturnsIdle() throws {
        let container = try AppContainer(inMemory: true)
        let model = CoachPhotoLibrarySelectionTestSupport.makeModel(container: container)
        let flow = CoachImagePickFlowController()

        XCTAssertEqual(flow.beginPhotoLibraryPick(model: model), .started)
        flow.handlePhotoLibraryPickerDismissed()

        XCTAssertEqual(flow.state, .idle)
        XCTAssertFalse(flow.isPhotoPickerPresented)
        XCTAssertTrue(flow.allowsAttachmentPick)
        XCTAssertNil(model.inputState.pendingImage)
        XCTAssertNil(model.inputState.imageError)
        XCTAssertFalse(model.inputState.isImageProcessing)
    }

    // MARK: - 5. Loader failure

    func testLoaderFailureShowsRetryableImageError() async throws {
        let container = try AppContainer(inMemory: true)
        let model = CoachPhotoLibrarySelectionTestSupport.makeModel(container: container)
        let flow = FakeCoachPhotoLibraryImageLoader(failure: .loadFailed).makeFlow()
        let item = CoachPhotoLibrarySelectionTestSupport.testPickerItem

        XCTAssertEqual(flow.beginPhotoLibraryPick(model: model), .started)
        let pickID = try XCTUnwrap(flow.activeLibraryPickSessionID)

        await CoachPhotoLibrarySelectionTestSupport.simulateCoachViewLibrarySelectionCallback(
            flow: flow,
            item: item,
            model: model,
            claimedPickID: pickID
        )

        XCTAssertEqual(model.inputState.imageError, .loadFailed)
        XCTAssertTrue(model.inputState.imageErrorSupportsRetry)
        XCTAssertEqual(
            model.inputState.imageErrorMessage,
            CoachResponseBuilder.mealPhotoError(.loadFailed)
        )
        XCTAssertEqual(model.inputState.pendingImage?.status, .failed)
        XCTAssertEqual(flow.state, .idle)
    }

    // MARK: - 6. Large image pipeline success

    func testLargeImagePipelineSuccessStillStages() async throws {
        let container = try AppContainer(inMemory: true)
        let model = CoachPhotoLibrarySelectionTestSupport.makeModel(container: container)
        let largeImage = CoachPhotoLibrarySelectionTestSupport.makeTestImage(
            size: CGSize(width: 4_032, height: 3_024),
            color: .systemOrange
        )
        let flow = CoachPhotoLibrarySelectionTestSupport.makeFlow(
            loading: largeImage,
            originalEstimatedBytes: 6_500_000
        )
        let item = CoachPhotoLibrarySelectionTestSupport.testPickerItem

        XCTAssertEqual(flow.beginPhotoLibraryPick(model: model), .started)
        let pickID = try XCTUnwrap(flow.activeLibraryPickSessionID)

        await CoachPhotoLibrarySelectionTestSupport.simulateCoachViewLibrarySelectionCallback(
            flow: flow,
            item: item,
            model: model,
            claimedPickID: pickID
        )

        let pending = try XCTUnwrap(model.inputState.pendingImage)
        XCTAssertEqual(pending.status, .ready)
        XCTAssertTrue(pending.hasValidReadyAttachment)
        XCTAssertLessThanOrEqual(pending.byteSize, CoachImageUploadConfig.default.maxUploadBytes)
        XCTAssertNil(model.inputState.imageError)
    }

    // MARK: - 7. Stale selection ignored

    func testStaleOldSelectionIsIgnoredAfterNewerPickStarts() async throws {
        let container = try AppContainer(inMemory: true)
        let model = CoachPhotoLibrarySelectionTestSupport.makeModel(container: container)
        let image = CoachPhotoLibrarySelectionTestSupport.makeTestImage()
        let flow = CoachPhotoLibrarySelectionTestSupport.makeFlow(loading: image)
        let item = CoachPhotoLibrarySelectionTestSupport.testPickerItem

        XCTAssertEqual(flow.beginPhotoLibraryPick(model: model), .started)
        let stalePickID = try XCTUnwrap(flow.activeLibraryPickSessionID)
        flow.handlePhotoLibraryPickerDismissed()

        XCTAssertEqual(flow.beginPhotoLibraryPick(model: model), .started)
        XCTAssertNotEqual(flow.activeLibraryPickSessionID, stalePickID)

        flow.markLibrarySelectionReceived(claimedPickID: stalePickID)
        XCTAssertFalse(flow.beginPhotoLibrarySelectionHandling())
        await flow.handlePhotoLibrarySelection(item, model: model)

        XCTAssertNil(model.inputState.pendingImage)
        XCTAssertNil(model.inputState.imageError)
        XCTAssertEqual(flow.state, .pickerPresented(.library))
    }

    // MARK: - 8. Remove during processing

    func testRemoveDuringProcessingPreventsStaleImageFromAttaching() async throws {
        let container = try AppContainer(inMemory: true)
        let model = CoachPhotoLibrarySelectionTestSupport.makeModel(container: container)
        let image = CoachPhotoLibrarySelectionTestSupport.makeTestImage()
        let fakeLoader = FakeCoachPhotoLibraryImageLoader(
            results: [
                .success(
                    CoachImagePipeline.PhotoLibraryLoadedImage(
                        image: image,
                        originalEstimatedBytes: 1_024
                    )
                )
            ],
            gateLoadAtIndex: 0
        )
        let flow = fakeLoader.makeFlow()
        let item = CoachPhotoLibrarySelectionTestSupport.testPickerItem

        XCTAssertEqual(flow.beginPhotoLibraryPick(model: model), .started)
        let pickID = try XCTUnwrap(flow.activeLibraryPickSessionID)
        flow.markLibrarySelectionReceived(claimedPickID: pickID)
        XCTAssertTrue(flow.beginPhotoLibrarySelectionHandling())

        let selectionTask = Task {
            await flow.handlePhotoLibrarySelection(item, model: model)
        }
        await Task.yield()
        await Task.yield()

        model.removeStagedMealPhoto()
        flow.handleAttachmentRemoved()
        fakeLoader.releaseGatedLoad()
        await selectionTask.value

        XCTAssertNil(model.inputState.pendingImage)
        XCTAssertNil(model.inputState.imageError)
        XCTAssertEqual(flow.state, .idle)
    }

    // MARK: - 9. Replacement preserves old image until success

    func testReplacementWithLibraryPreservesOldImageUntilSuccess() async throws {
        let container = try AppContainer(inMemory: true)
        let model = CoachPhotoLibrarySelectionTestSupport.makeModel(container: container)
        let firstImage = CoachPhotoLibrarySelectionTestSupport.makeTestImage(color: .systemBlue)
        let secondImage = CoachPhotoLibrarySelectionTestSupport.makeTestImage(
            size: CGSize(width: 800, height: 600),
            color: .systemGreen
        )
        let fakeLoader = FakeCoachPhotoLibraryImageLoader(
            results: [
                .success(CoachImagePipeline.PhotoLibraryLoadedImage(image: firstImage, originalEstimatedBytes: 900)),
                .success(CoachImagePipeline.PhotoLibraryLoadedImage(image: secondImage, originalEstimatedBytes: 1_100))
            ],
            gateLoadAtIndex: 1
        )
        let flow = fakeLoader.makeFlow()
        let item = CoachPhotoLibrarySelectionTestSupport.testPickerItem

        XCTAssertEqual(flow.beginPhotoLibraryPick(model: model), .started)
        let firstPickID = try XCTUnwrap(flow.activeLibraryPickSessionID)
        await CoachPhotoLibrarySelectionTestSupport.simulateCoachViewLibrarySelectionCallback(
            flow: flow,
            item: item,
            model: model,
            claimedPickID: firstPickID
        )

        let firstID = try XCTUnwrap(model.inputState.pendingImage?.id)
        let firstUpload = try XCTUnwrap(model.inputState.pendingImage?.uploadData)

        XCTAssertEqual(flow.beginPhotoLibraryPick(model: model), .started)
        let secondPickID = try XCTUnwrap(flow.activeLibraryPickSessionID)
        flow.markLibrarySelectionReceived(claimedPickID: secondPickID)
        XCTAssertTrue(flow.beginPhotoLibrarySelectionHandling())

        let replacementTask = Task {
            await flow.handlePhotoLibrarySelection(item, model: model)
        }
        await Task.yield()
        await Task.yield()

        XCTAssertEqual(model.inputState.pendingImage?.id, firstID)
        XCTAssertEqual(model.inputState.pendingImage?.uploadData, firstUpload)
        XCTAssertEqual(model.inputState.pendingImage?.status, .processing)
        XCTAssertTrue(model.inputState.pendingImage?.showsComposerPreview == true)

        fakeLoader.releaseGatedLoad()
        await replacementTask.value

        let pending = try XCTUnwrap(model.inputState.pendingImage)
        XCTAssertNotEqual(pending.id, firstID)
        XCTAssertNotEqual(pending.uploadData, firstUpload)
        XCTAssertEqual(pending.status, .ready)
        XCTAssertEqual(pending.source, .library)
    }

    // MARK: - 10. Camera regression

    func testCameraCaptureStillPassesAfterLibrarySelectionSeam() async throws {
        let container = try AppContainer(inMemory: true)
        let model = CoachPhotoLibrarySelectionTestSupport.makeModel(container: container)
        let flow = CoachImagePickFlowController()
        let image = CoachPhotoLibrarySelectionTestSupport.makeTestImage()

        flow.setStateForTests(.pickerPresented(.camera))
        await flow.handleCameraResult(.success(image), model: model)

        XCTAssertEqual(flow.state, .idle)
        XCTAssertEqual(model.inputState.pendingImage?.source, .camera)
        XCTAssertEqual(model.inputState.pendingImage?.status, .ready)
        XCTAssertTrue(model.inputState.pendingImage?.hasValidReadyAttachment == true)
    }
}
