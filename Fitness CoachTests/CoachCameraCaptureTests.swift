//
//  CoachCameraCaptureTests.swift
//  Fitness CoachTests
//
//  Forma — Camera JPEG preparation for Coach attachments.
//

import UIKit
import XCTest
@testable import Fitness_Coach

final class CoachCameraCaptureTests: XCTestCase {

    func testProcessImageFromUIImageProducesPayload() {
        let image = Self.makeTestImage()
        guard case .success(let processed) = CoachImagePipeline.process(image: image) else {
            return XCTFail("Expected JPEG from camera image")
        }
        XCTAssertTrue(CoachMealPhotoPipeline.hasImagePayload(processed.uploadData))
    }

    func testProcessImageFromUIImageRejectsInvalidInput() {
        let image = UIImage()
        XCTAssertEqual(
            CoachImagePipeline.process(image: image),
            .failure(.invalidInput)
        )
    }

    private static func makeTestImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 12, height: 12))
        return renderer.image { context in
            UIColor.orange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 12, height: 12))
        }
    }
}
