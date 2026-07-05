//
//  CoachPendingImageAttachmentUnifiedTests.swift
//  Fitness CoachTests
//
//  Unified pending-image attachment contract for camera and library paths.
//

import PhotosUI
import UIKit
import XCTest
@testable import Fitness_Coach

@MainActor
final class CoachPendingImageAttachmentUnifiedTests: XCTestCase {

    // MARK: - Attach into pendingImage

    func testCameraAttachesImageIntoPendingImage() async throws {
        let container = try AppContainer(inMemory: true)
        let model = makeModel(container: container)
        let flow = CoachImagePickFlowController()
        let image = makeTestImage(size: CGSize(width: 800, height: 600), color: .systemBlue)

        flow.setStateForTests(.pickerPresented(.camera))
        await flow.handleCameraResult(.success(image), model: model)

        let pending = try XCTUnwrap(model.inputState.pendingImage)
        assertUnifiedReadyAttachment(pending, source: .camera)
        XCTAssertNotNil(model.pendingImageLocalSource(for: try XCTUnwrap(pending.localReferenceID)))
    }

    func testLibraryAttachesImageIntoPendingImage() async throws {
        let container = try AppContainer(inMemory: true)
        let model = makeModel(container: container)
        let image = makeTestImage(size: CGSize(width: 900, height: 700), color: .systemGreen)
        let flow = CoachImagePickFlowController { _ in
            .success(
                CoachImagePipeline.PhotoLibraryLoadedImage(
                    image: image,
                    originalEstimatedBytes: 1_024
                )
            )
        }
        let item = PhotosPickerItem(itemIdentifier: "coach-unified-library-attach-test")

        XCTAssertEqual(flow.beginPhotoLibraryPick(model: model), .started)
        let pickID = try XCTUnwrap(flow.activeLibraryPickSessionID)
        await simulateLibrarySelection(flow: flow, item: item, model: model, pickID: pickID)

        let pending = try XCTUnwrap(model.inputState.pendingImage)
        assertUnifiedReadyAttachment(pending, source: .library)
        XCTAssertNotNil(model.pendingImageLocalSource(for: try XCTUnwrap(pending.localReferenceID)))
    }

    // MARK: - Preview parity

    func testLibraryImageRendersSamePreviewEligibilityAsCamera() async throws {
        let container = try AppContainer(inMemory: true)
        let model = makeModel(container: container)
        let cameraFlow = CoachImagePickFlowController()
        let libraryFlow = CoachImagePickFlowController { _ in
            .success(
                CoachImagePipeline.PhotoLibraryLoadedImage(
                    image: makeTestImage(size: CGSize(width: 640, height: 480), color: .systemTeal),
                    originalEstimatedBytes: 900
                )
            )
        }

        cameraFlow.setStateForTests(.pickerPresented(.camera))
        await cameraFlow.handleCameraResult(
            .success(makeTestImage(size: CGSize(width: 640, height: 480), color: .systemTeal)),
            model: model
        )
        let cameraPending = try XCTUnwrap(model.inputState.pendingImage)

        model.removeStagedMealPhoto()
        cameraFlow.handleAttachmentRemoved()

        XCTAssertEqual(libraryFlow.beginPhotoLibraryPick(model: model), .started)
        let pickID = try XCTUnwrap(libraryFlow.activeLibraryPickSessionID)
        await simulateLibrarySelection(
            flow: libraryFlow,
            item: PhotosPickerItem(itemIdentifier: "coach-unified-preview-parity-test"),
            model: model,
            pickID: pickID
        )
        let libraryPending = try XCTUnwrap(model.inputState.pendingImage)

        XCTAssertTrue(cameraPending.showsComposerPreview)
        XCTAssertTrue(libraryPending.showsComposerPreview)
        XCTAssertTrue(cameraPending.hasValidReadyAttachment)
        XCTAssertTrue(libraryPending.hasValidReadyAttachment)
        XCTAssertFalse(cameraPending.thumbnail.isEmpty)
        XCTAssertFalse(libraryPending.thumbnail.isEmpty)
        XCTAssertNotEqual(cameraPending.thumbnail, cameraPending.uploadData)
        XCTAssertNotEqual(libraryPending.thumbnail, libraryPending.uploadData)
    }

    // MARK: - Remove

    func testRemovingLibraryImageClearsComposer() async throws {
        let container = try AppContainer(inMemory: true)
        let model = makeModel(container: container)
        let flow = makeLibraryFlow(image: makeTestImage(size: CGSize(width: 500, height: 400)))

        XCTAssertEqual(flow.beginPhotoLibraryPick(model: model), .started)
        let pickID = try XCTUnwrap(flow.activeLibraryPickSessionID)
        await simulateLibrarySelection(
            flow: flow,
            item: PhotosPickerItem(itemIdentifier: "coach-unified-remove-test"),
            model: model,
            pickID: pickID
        )
        let localReferenceID = try XCTUnwrap(model.inputState.pendingImage?.localReferenceID)

        model.removeStagedMealPhoto()
        flow.handleAttachmentRemoved()

        XCTAssertNil(model.inputState.pendingImage)
        XCTAssertNil(model.inputState.imageError)
        XCTAssertNil(model.pendingImageLocalSource(for: localReferenceID))
        XCTAssertTrue(model.inputState.canStartImageSelection)
        XCTAssertEqual(flow.state, .idle)
        XCTAssertFalse(flow.isPhotoPickerPresented)
    }

    // MARK: - Replacement

    func testReplacingCameraImageWithLibraryImageWorks() async throws {
        let container = try AppContainer(inMemory: true)
        let model = makeModel(container: container)
        let flow = CoachImagePickFlowController { _ in
            .success(
                CoachImagePipeline.PhotoLibraryLoadedImage(
                    image: makeTestImage(size: CGSize(width: 700, height: 500), color: .systemGreen),
                    originalEstimatedBytes: 1_100
                )
            )
        }
        let cameraImage = makeTestImage(size: CGSize(width: 600, height: 600), color: .systemBlue)

        flow.setStateForTests(.pickerPresented(.camera))
        await flow.handleCameraResult(.success(cameraImage), model: model)
        let cameraUpload = try XCTUnwrap(model.inputState.pendingImage?.uploadData)
        let cameraID = try XCTUnwrap(model.inputState.pendingImage?.id)

        XCTAssertEqual(flow.beginPhotoLibraryPick(model: model), .started)
        let pickID = try XCTUnwrap(flow.activeLibraryPickSessionID)
        flow.markLibrarySelectionReceived(claimedPickID: pickID)
        XCTAssertTrue(flow.beginPhotoLibrarySelectionHandling())
        XCTAssertTrue(model.inputState.pendingImage?.showsComposerPreview == true)
        XCTAssertEqual(model.inputState.pendingImage?.uploadData, cameraUpload)
        XCTAssertEqual(model.inputState.pendingImage?.id, cameraID)

        await flow.handlePhotoLibrarySelection(
            PhotosPickerItem(itemIdentifier: "coach-unified-camera-to-library"),
            model: model
        )

        let pending = try XCTUnwrap(model.inputState.pendingImage)
        assertUnifiedReadyAttachment(pending, source: .library)
        XCTAssertNotEqual(pending.id, cameraID)
        XCTAssertNotEqual(pending.uploadData, cameraUpload)
    }

    func testReplacingLibraryImageWithCameraImageWorks() async throws {
        let container = try AppContainer(inMemory: true)
        let model = makeModel(container: container)
        let flow = makeLibraryFlow(image: makeTestImage(size: CGSize(width: 640, height: 480), color: .systemOrange))

        XCTAssertEqual(flow.beginPhotoLibraryPick(model: model), .started)
        let pickID = try XCTUnwrap(flow.activeLibraryPickSessionID)
        await simulateLibrarySelection(
            flow: flow,
            item: PhotosPickerItem(itemIdentifier: "coach-unified-library-first"),
            model: model,
            pickID: pickID
        )
        let libraryUpload = try XCTUnwrap(model.inputState.pendingImage?.uploadData)
        let libraryID = try XCTUnwrap(model.inputState.pendingImage?.id)

        let cameraImage = makeTestImage(size: CGSize(width: 720, height: 540), color: .systemPurple)
        flow.setStateForTests(.pickerPresented(.camera))
        await flow.handleCameraResult(.success(cameraImage), model: model)

        let pending = try XCTUnwrap(model.inputState.pendingImage)
        assertUnifiedReadyAttachment(pending, source: .camera)
        XCTAssertNotEqual(pending.id, libraryID)
        XCTAssertNotEqual(pending.uploadData, libraryUpload)
    }

    func testFailedLibraryReplacementPreservesOldImage() async throws {
        let container = try AppContainer(inMemory: true)
        let model = makeModel(container: container)
        var shouldFail = false
        let flow = CoachImagePickFlowController { _ in
            if shouldFail {
                return .failure(.loadFailed)
            }
            return .success(
                CoachImagePipeline.PhotoLibraryLoadedImage(
                    image: makeTestImage(size: CGSize(width: 500, height: 500), color: .systemGreen),
                    originalEstimatedBytes: 800
                )
            )
        }

        XCTAssertEqual(flow.beginPhotoLibraryPick(model: model), .started)
        let firstPickID = try XCTUnwrap(flow.activeLibraryPickSessionID)
        await simulateLibrarySelection(
            flow: flow,
            item: PhotosPickerItem(itemIdentifier: "coach-unified-replacement-first"),
            model: model,
            pickID: firstPickID
        )

        let originalID = try XCTUnwrap(model.inputState.pendingImage?.id)
        let originalUpload = try XCTUnwrap(model.inputState.pendingImage?.uploadData)
        let originalReferenceID = try XCTUnwrap(model.inputState.pendingImage?.localReferenceID)

        shouldFail = true
        XCTAssertEqual(flow.beginPhotoLibraryPick(model: model), .started)
        let secondPickID = try XCTUnwrap(flow.activeLibraryPickSessionID)
        flow.markLibrarySelectionReceived(claimedPickID: secondPickID)
        XCTAssertTrue(flow.beginPhotoLibrarySelectionHandling())
        await flow.handlePhotoLibrarySelection(
            PhotosPickerItem(itemIdentifier: "coach-unified-replacement-failed"),
            model: model
        )

        let pending = try XCTUnwrap(model.inputState.pendingImage)
        XCTAssertEqual(pending.id, originalID)
        XCTAssertEqual(pending.uploadData, originalUpload)
        XCTAssertEqual(pending.localReferenceID, originalReferenceID)
        XCTAssertEqual(pending.status, .ready)
        XCTAssertEqual(pending.source, .library)
        XCTAssertEqual(model.inputState.imageError, .loadFailed)
        XCTAssertTrue(pending.showsComposerPreview)
        XCTAssertNotNil(model.pendingImageLocalSource(for: originalReferenceID))
    }

    // MARK: - Helpers

    private func makeModel(container: AppContainer) -> CoachModel {
        CoachModel(
            actionCenter: container.actionCenter,
            dailyLogReader: container.dailyLogService,
            healthActivityQuery: container.healthActivityQueryService
        )
    }

    private func makeLibraryFlow(image: UIImage) -> CoachImagePickFlowController {
        CoachImagePickFlowController { _ in
            .success(
                CoachImagePipeline.PhotoLibraryLoadedImage(
                    image: image,
                    originalEstimatedBytes: 1_024
                )
            )
        }
    }

    private func simulateLibrarySelection(
        flow: CoachImagePickFlowController,
        item: PhotosPickerItem,
        model: CoachModel,
        pickID: UUID
    ) async {
        flow.markLibrarySelectionReceived(claimedPickID: pickID)
        XCTAssertTrue(flow.beginPhotoLibrarySelectionHandling())
        await flow.handlePhotoLibrarySelection(item, model: model)
    }

    private func assertUnifiedReadyAttachment(
        _ pending: CoachPendingImageState,
        source: CoachInputAttachmentSource,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(pending.hasValidReadyAttachment, file: file, line: line)
        XCTAssertEqual(pending.status, .ready, file: file, line: line)
        XCTAssertEqual(pending.source, source, file: file, line: line)
        XCTAssertFalse(pending.thumbnail.isEmpty, file: file, line: line)
        XCTAssertFalse(pending.uploadData.isEmpty, file: file, line: line)
        XCTAssertNotNil(pending.localReferenceID, file: file, line: line)
        XCTAssertNotEqual(pending.thumbnail, pending.uploadData, file: file, line: line)
        XCTAssertTrue(pending.showsComposerPreview, file: file, line: line)
    }

    private func makeTestImage(size: CGSize, color: UIColor) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}

@MainActor
private extension CoachImagePickFlowController {
    func setStateForTests(_ newState: CoachImagePickFlowState) {
        state = newState
    }
}
