//
//  CoachImageProcessingLoggerTests.swift
//  Fitness CoachTests
//
//  Coach image processing analytics field mapping.
//

import XCTest
@testable import Fitness_Coach

final class CoachImageProcessingLoggerTests: XCTestCase {

    func testSuccessEventFieldsUseRequestedAnalyticsKeys() {
        let event = CoachImageProcessingAnalyticsEvent(
            imageSource: "photo_library",
            originalWidth: 4_032,
            originalHeight: 3_024,
            processedWidth: 1_280,
            processedHeight: 960,
            finalByteSize: 245_000,
            compressionStrategy: CoachImagePipelineCompressionStrategy.initial.rawValue,
            processingDurationMs: 128,
            success: true,
            failureReason: nil
        )

        let fields = event.fields

        XCTAssertEqual(fields["image_source"], "photo_library")
        XCTAssertEqual(fields["original_width"], "4032")
        XCTAssertEqual(fields["original_height"], "3024")
        XCTAssertEqual(fields["processed_width"], "1280")
        XCTAssertEqual(fields["processed_height"], "960")
        XCTAssertEqual(fields["final_byte_size"], "245000")
        XCTAssertEqual(fields["compression_strategy"], "initial")
        XCTAssertEqual(fields["processing_duration_ms"], "128")
        XCTAssertEqual(fields["success"], "true")
        XCTAssertNil(fields["failure_reason"])
    }

    func testFailureEventIncludesFailureReasonOnly() {
        let event = CoachImageProcessingAnalyticsEvent(
            imageSource: "camera",
            originalWidth: 1_920,
            originalHeight: 1_080,
            processedWidth: nil,
            processedHeight: nil,
            finalByteSize: nil,
            compressionStrategy: nil,
            processingDurationMs: 42,
            success: false,
            failureReason: "encoding_failed"
        )

        let fields = event.fields

        XCTAssertEqual(fields["image_source"], "camera")
        XCTAssertEqual(fields["success"], "false")
        XCTAssertEqual(fields["failure_reason"], "encoding_failed")
        XCTAssertNil(fields["processed_width"])
        XCTAssertNil(fields["final_byte_size"])
    }

    func testAnalyticsSourceLabelsMatchContract() {
        XCTAssertEqual(CoachImageProcessingLogger.analyticsSourceLabel(.camera), "camera")
        XCTAssertEqual(CoachImageProcessingLogger.analyticsSourceLabel(.library), "photo_library")
    }

    func testFailureReasonMapsPipelineAndSelectionErrors() {
        XCTAssertEqual(
            CoachImageProcessingLogger.failureReason(for: CoachImagePipelineError.exceedsMaxSize(maxBytes: 500_000)),
            "payload_too_large"
        )
        XCTAssertEqual(
            CoachImageProcessingLogger.failureReason(for: CoachMealPhotoError.loadFailed),
            "load_failed"
        )
    }

    func testFieldsNeverIncludeImageContentOrMetadataKeys() {
        let event = CoachImageProcessingAnalyticsEvent(
            imageSource: "photo_library",
            originalWidth: 100,
            originalHeight: 100,
            processedWidth: 80,
            processedHeight: 80,
            finalByteSize: 1_024,
            compressionStrategy: "initial",
            processingDurationMs: 10,
            success: true,
            failureReason: nil
        )

        let forbidden = [
            "base64", "jpeg", "image_data", "upload_data", "thumbnail",
            "exif", "gps", "location", "latitude", "longitude", "metadata"
        ]

        for key in event.fields.keys {
            for banned in forbidden {
                XCTAssertFalse(
                    key.localizedCaseInsensitiveContains(banned),
                    "Unexpected sensitive key: \(key)"
                )
            }
        }
    }
}
