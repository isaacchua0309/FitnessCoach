//
//  CoachPhotoLibrarySelectionTestSupport.swift
//  Fitness CoachTests
//
//  Shared harness for unit-testing the library selection controller path
//  without presenting the system PhotosPicker.
//

import PhotosUI
import UIKit
import XCTest
@testable import Fitness_Coach

@MainActor
enum CoachPhotoLibrarySelectionTestSupport {

    /// Fixture item for tests; injected loaders never read from Photos.
    static var testPickerItem: PhotosPickerItem {
        PhotosPickerItem(itemIdentifier: "coach-photo-library-selection-test-fixture")
    }

    static func makeModel(container: AppContainer) -> CoachModel {
        CoachModelTestFactory.makeModel(
            actionCenter: container.actionCenter,
            dailyLogReader: container.dailyLogService,
            healthActivityQuery: container.healthActivityQueryService
        )
    }

    static func makeTestImage(
        size: CGSize = CGSize(width: 640, height: 480),
        color: UIColor = .systemTeal
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    /// Injected loader that returns a fixed image for every selection.
    static func makeFlow(loading image: UIImage, originalEstimatedBytes: Int = 1_024) -> CoachImagePickFlowController {
        FakeCoachPhotoLibraryImageLoader(image: image, originalEstimatedBytes: originalEstimatedBytes).makeFlow()
    }

    /// Mirrors the production `CoachView` library selection callback.
    static func simulateCoachViewLibrarySelectionCallback(
        flow: CoachImagePickFlowController,
        item: PhotosPickerItem,
        model: CoachModel,
        claimedPickID: UUID
    ) async {
        flow.markLibrarySelectionReceived(claimedPickID: claimedPickID)
        let selectionWasAccepted = flow.debugLibrarySelectionReceivedForLogging()
        guard flow.beginPhotoLibrarySelectionHandling() else {
            if selectionWasAccepted {
                flow.handleDroppedLibrarySelection(model: model)
            }
            return
        }
        await flow.handlePhotoLibrarySelection(item, model: model)
    }
}

/// Deterministic stand-in for `CoachImagePipeline.loadImageFromPhotoLibrary`.
final class FakeCoachPhotoLibraryImageLoader: @unchecked Sendable {

    private let lock = NSLock()
    private var results: [Result<CoachImagePipeline.PhotoLibraryLoadedImage, CoachMealPhotoError>]
    private var loadIndex = 0
    private var gateLoadAtIndex: Int?
    private var releaseGate: (() -> Void)?

    init(
        results: [Result<CoachImagePipeline.PhotoLibraryLoadedImage, CoachMealPhotoError>],
        gateLoadAtIndex: Int? = nil
    ) {
        self.results = results
        self.gateLoadAtIndex = gateLoadAtIndex
    }

    convenience init(
        image: UIImage,
        originalEstimatedBytes: Int = 1_024,
        gateLoadAtIndex: Int? = nil
    ) {
        self.init(
            results: [
                .success(
                    CoachImagePipeline.PhotoLibraryLoadedImage(
                        image: image,
                        originalEstimatedBytes: originalEstimatedBytes
                    )
                )
            ],
            gateLoadAtIndex: gateLoadAtIndex
        )
    }

    convenience init(failure: CoachMealPhotoError) {
        self.init(results: [.failure(failure)])
    }

    var loader: CoachPhotoLibraryImageLoader {
        { [weak self] item in
            guard let self else { return .failure(.noImage) }
            return await self.load(item)
        }
    }

    func makeFlow() -> CoachImagePickFlowController {
        CoachImagePickFlowController(photoLibraryImageLoader: loader)
    }

    private func load(_ item: PhotosPickerItem) async -> Result<CoachImagePipeline.PhotoLibraryLoadedImage, CoachMealPhotoError> {
        let currentIndex = lock.withLock { loadIndex }
        if gateLoadAtIndex == currentIndex {
            await withCheckedContinuation { continuation in
                lock.lock()
                releaseGate = { continuation.resume() }
                lock.unlock()
            }
        }

        return lock.withLock {
            let index = min(loadIndex, results.count - 1)
            loadIndex += 1
            return results[index]
        }
    }

    func releaseGatedLoad() {
        lock.lock()
        releaseGate?()
        releaseGate = nil
        lock.unlock()
    }
}

@MainActor
extension CoachImagePickFlowController {
    func setStateForTests(_ newState: CoachImagePickFlowState) {
        state = newState
    }
}

// Backward-compatible alias for existing race regression tests.
typealias CoachPhotoLibrarySelectionRaceTestSupport = CoachPhotoLibrarySelectionTestSupport
