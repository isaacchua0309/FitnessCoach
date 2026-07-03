//
//  CoachImageUploadConfigTests.swift
//  Fitness CoachTests
//
//  Centralized Coach image upload configuration defaults and gateway alignment.
//

import XCTest
@testable import Fitness_Coach

final class CoachImageUploadConfigTests: XCTestCase {

    func testDefaultValuesMatchCentralizedSpec() {
        let config = CoachImageUploadConfig.default

        XCTAssertEqual(config.maxUploadBytes, 500_000)
        XCTAssertEqual(config.preferredLongestSide, 1_280)
        XCTAssertEqual(config.fallbackLongestSide, 1_024)
        XCTAssertEqual(config.thumbnailLongestSide, 240)
        XCTAssertEqual(config.preferredJPEGQuality, 0.8, accuracy: 0.001)
        XCTAssertEqual(config.fallbackJPEGQuality, 0.7, accuracy: 0.001)
        XCTAssertEqual(config.aggressiveJPEGQuality, 0.6, accuracy: 0.001)
        XCTAssertEqual(config.mimeType, "image/jpeg")
    }

    func testGatewayLimitsDeriveFromUploadConfig() {
        let config = CoachImageUploadConfig.default

        XCTAssertEqual(AIGatewayPayloadLimits.maxJPEGBytes, config.maxUploadBytes)
        XCTAssertEqual(AIGatewayPayloadLimits.maxImageBase64Characters, config.maxBase64CharacterLimit)
        XCTAssertEqual(AIGatewayPayloadLimits.maxRequestBodyBytes, config.maxRequestBodyBytes)
    }

    func testProcessingConfigDerivesFromUploadConfig() {
        let upload = CoachImageUploadConfig.default
        let processing = CoachImageProcessingConfig.default

        XCTAssertEqual(processing.uploadLongestSide, upload.preferredLongestSide)
        XCTAssertEqual(processing.fallbackLongestSide, upload.fallbackLongestSide)
        XCTAssertEqual(processing.initialJPEGQuality, upload.preferredJPEGQuality)
        XCTAssertEqual(processing.reducedJPEGQuality, upload.fallbackJPEGQuality)
        XCTAssertEqual(processing.minimumJPEGQuality, upload.aggressiveJPEGQuality)
        XCTAssertEqual(processing.thumbnailMaxEdge, upload.thumbnailLongestSide)
        XCTAssertEqual(processing.maxUploadBytes, upload.maxUploadBytes)
        XCTAssertEqual(processing.uploadMIMEType, upload.mimeType)
    }
}
