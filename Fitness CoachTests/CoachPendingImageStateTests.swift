//
//  CoachPendingImageStateTests.swift
//  Fitness CoachTests
//
//  CoachPendingImageState factories and lifecycle helpers.
//

import UIKit
import XCTest
@testable import Fitness_Coach

final class CoachPendingImageStateTests: XCTestCase {

    func testFromProcessedImageSeparatesThumbnailAndUploadData() {
        let sourceImage = makeTestImage(size: CGSize(width: 800, height: 600))
        guard case .success(let processed) = CoachImagePipeline.process(image: sourceImage) else {
            return XCTFail("Expected processed image")
        }

        let pending = CoachPendingImageState.from(
            processed: processed,
            source: .library,
            originalEstimatedBytes: 900_000,
            localReferenceID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")
        )

        XCTAssertEqual(pending.thumbnail, processed.thumbnailData)
        XCTAssertEqual(pending.uploadData, processed.uploadData)
        XCTAssertNotEqual(pending.thumbnail, pending.uploadData)
        XCTAssertEqual(pending.mimeType, processed.uploadMIMEType)
        XCTAssertEqual(pending.processedSize, processed.processedPixelSize)
        XCTAssertEqual(pending.byteSize, processed.finalByteSize)
        XCTAssertEqual(pending.status, .ready)
        XCTAssertEqual(pending.compressionStrategy, processed.compressionStrategy)
        XCTAssertTrue(pending.isPipelineProcessedUpload)
    }

    func testProcessingPreservesReadyPayloadUntilReplacement() {
        let ready = CoachPendingImageState.legacyReady(
            uploadData: Data([0x01, 0x02]),
            thumbnail: Data([0x03]),
            source: .camera
        )

        let processing = CoachPendingImageState.processing(source: .library, preserving: ready)

        XCTAssertEqual(processing.id, ready.id)
        XCTAssertEqual(processing.uploadData, ready.uploadData)
        XCTAssertEqual(processing.thumbnail, ready.thumbnail)
        XCTAssertEqual(processing.status, .processing)
        XCTAssertEqual(processing.source, .library)
    }

    private func makeTestImage(size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.systemOrange.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}
