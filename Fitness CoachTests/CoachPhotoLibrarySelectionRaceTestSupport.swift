//
//  CoachPhotoLibrarySelectionRaceTestSupport.swift
//  Fitness CoachTests
//
//  Test helpers for Coach photo library picker race regressions.
//

import PhotosUI
import UIKit
import XCTest
@testable import Fitness_Coach

@MainActor
enum CoachPhotoLibrarySelectionRaceTestSupport {

    /// Injected loader that ignores `PhotosPickerItem` and returns a fixed test image.
    static func makeFlow(loading image: UIImage) -> CoachImagePickFlowController {
        CoachImagePickFlowController { _ in
            .success(
                CoachImagePipeline.PhotoLibraryLoadedImage(
                    image: image,
                    originalEstimatedBytes: 1_024
                )
            )
        }
    }

    /// Fixture item for tests; loader injection means content is never read from Photos.
    static var testPickerItem: PhotosPickerItem {
        PhotosPickerItem(itemIdentifier: "coach-photo-library-race-test-fixture")
    }

    /// Mirrors the production `CoachView` library selection callback.
    static func simulateCoachViewLibrarySelectionCallback(
        flow: CoachImagePickFlowController,
        item: PhotosPickerItem,
        model: CoachModel,
        claimedPickID: UUID
    ) async {
        flow.markLibrarySelectionReceived(claimedPickID: claimedPickID)
        guard flow.beginPhotoLibrarySelectionHandling() else { return }
        await flow.handlePhotoLibrarySelection(item, model: model)
    }

    static func makeModel(container: AppContainer) -> CoachModel {
        CoachModel(
            actionCenter: container.actionCenter,
            dailyLogReader: container.dailyLogService,
            healthActivityQuery: container.healthActivityQueryService
        )
    }

    static func makeTestImage(size: CGSize = CGSize(width: 640, height: 480)) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}
