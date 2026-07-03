//
//  CoachMealPhotoPipelineTests.swift
//  Fitness CoachTests
//
//  Gateway-aligned meal photo compression regressions.
//

import UIKit
import XCTest
@testable import Fitness_Coach

final class CoachMealPhotoPipelineTests: XCTestCase {

    func testLargePhotoCompressesUnderGatewayLimits() {
        let raw = Self.makeLargeTestJPEGData()
        guard case .success(let prepared) = CoachMealPhotoPipeline.prepareJPEGSync(from: raw) else {
            return XCTFail("Expected compressed JPEG payload")
        }

        XCTAssertTrue(AIGatewayPayloadLimits.fitsImagePayload(prepared))
        XCTAssertLessThanOrEqual(
            AIGatewayPayloadLimits.estimatedBase64CharacterCount(for: prepared),
            AIGatewayPayloadLimits.maxImageBase64Characters
        )
    }

    func testEstimatedBodySizeIncludesImageEnvelope() {
        let jpeg = Self.makeTestJPEGData()
        let estimated = AIGatewayPayloadLimits.estimatedEstimateFoodBodyBytes(
            text: CoachMealPhotoPipeline.defaultAnalysisPrompt,
            imageJPEGData: jpeg
        )
        XCTAssertGreaterThan(estimated, jpeg.count)
        XCTAssertLessThan(estimated, AIGatewayPayloadLimits.maxRequestBodyBytes)
    }

    private static func makeTestJPEGData() -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 12, height: 12))
        let image = renderer.image { context in
            UIColor.orange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 12, height: 12))
        }
        return image.jpegData(compressionQuality: 0.85)!
    }

    private static func makeLargeTestJPEGData() -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 4_032, height: 3_024))
        let image = renderer.image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 4_032, height: 3_024))
            UIColor.systemPink.setFill()
            context.fill(CGRect(x: 400, y: 300, width: 2_800, height: 2_000))
        }
        guard let jpeg = image.jpegData(compressionQuality: 0.95) else {
            XCTFail("Expected large JPEG sample")
            return Data()
        }
        XCTAssertGreaterThan(jpeg.count, AIGatewayPayloadLimits.maxJPEGBytes)
        return jpeg
    }
}
