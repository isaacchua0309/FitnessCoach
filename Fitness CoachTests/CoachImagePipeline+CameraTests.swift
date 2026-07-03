//
//  CoachImagePipeline+CameraTests.swift
//  Fitness CoachTests
//
//  Camera import path for CoachImagePipeline.
//

import UIKit
import XCTest
@testable import Fitness_Coach

final class CoachImagePipelineCameraTests: XCTestCase {

    func testImportFromCameraReturnsProcessedUploadPayload() async {
        let image = Self.makeTestImage(size: CGSize(width: 1_600, height: 1_200))
        let result = await CoachImagePipeline.importFromCamera(image)

        guard case .success(let imported) = result else {
            return XCTFail("Expected camera import success, got \(result)")
        }

        XCTAssertNil(imported.originalEstimatedBytes)
        XCTAssertFalse(imported.processed.uploadData.isEmpty)
        XCTAssertFalse(imported.processed.thumbnailData.isEmpty)
        XCTAssertLessThanOrEqual(
            imported.processed.uploadData.count,
            CoachImageUploadConfig.default.maxUploadBytes
        )
    }

    private static func makeTestImage(size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}
