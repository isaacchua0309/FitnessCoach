//
//  CoachMealImageAIRequestBuilderTests.swift
//  Fitness CoachTests
//
//  Coach meal-image AI request builder and upload validation.
//

import UIKit
import XCTest
@testable import Fitness_Coach

final class CoachMealImageAIRequestBuilderTests: XCTestCase {

    func testBuildsRequestFromCompressedUploadData() throws {
        let sourceImage = makeTestImage(size: CGSize(width: 640, height: 480))
        guard case .success(let processed) = CoachImagePipeline.process(image: sourceImage) else {
            return XCTFail("Expected pipeline success")
        }

        let attachment = CoachMealImageUploadAttachment.from(processed: processed)
        let result = CoachMealImageAIRequestBuilder.buildAnalysisRequest(
            attachment: attachment,
            context: .test,
            message: "Lunch bowl"
        )

        let request = try XCTUnwrap(result.successValue)
        XCTAssertEqual(request.image.mimeType, CoachImageUploadConfig.default.mimeType)
        XCTAssertEqual(request.image.filename, CoachMealImageAIRequestBuilder.defaultFilename)
        XCTAssertEqual(request.message, "Lunch bowl")
        XCTAssertEqual(request.image.base64, processed.uploadData.base64EncodedString())
        XCTAssertEqual(Data(base64Encoded: request.image.base64), processed.uploadData)
        XCTAssertEqual(request.image.width, processed.processedPixelSize.width)
        XCTAssertEqual(request.image.height, processed.processedPixelSize.height)
        XCTAssertLessThanOrEqual(processed.uploadData.count, CoachImageUploadConfig.default.maxUploadBytes)
    }

    func testUniqueFilenameUsesUUIDSuffix() {
        let first = CoachMealImageAIRequestBuilder.uniqueFilename()
        let second = CoachMealImageAIRequestBuilder.uniqueFilename()

        XCTAssertTrue(first.hasSuffix(".jpg"))
        XCTAssertTrue(second.hasSuffix(".jpg"))
        XCTAssertNotEqual(first, second)
    }

    func testRejectsEmptyUploadDataBeforeNetwork() {
        let attachment = CoachMealImageUploadAttachment(
            uploadData: Data(),
            filename: CoachMealImageAIRequestBuilder.defaultFilename
        )

        switch CoachMealImageAIRequestBuilder.validate(attachment) {
        case .failure(.emptyUploadData):
            break
        default:
            XCTFail("Expected empty upload data validation failure")
        }
        XCTAssertEqual(
            CoachMealImageAIRequestBuilder.mapBuildError(.emptyUploadData),
            .imageEncodingFailed
        )
    }

    func testRejectsOversizedUploadDataBeforeNetwork() {
        let maxBytes = CoachImageUploadConfig.default.maxUploadBytes
        let oversized = Data(repeating: 0xFF, count: maxBytes + 1)
        let attachment = CoachMealImageUploadAttachment(
            uploadData: oversized,
            filename: CoachMealImageAIRequestBuilder.defaultFilename
        )

        switch CoachMealImageAIRequestBuilder.validate(attachment) {
        case .failure(.uploadExceedsMaxBytes(let byteCount, let limit)):
            XCTAssertEqual(byteCount, maxBytes + 1)
            XCTAssertEqual(limit, maxBytes)
        default:
            XCTFail("Expected oversized upload validation failure")
        }
        XCTAssertEqual(
            CoachMealImageAIRequestBuilder.mapBuildError(
                .uploadExceedsMaxBytes(byteCount: maxBytes + 1, maxBytes: maxBytes)
            ),
            .imageEncodingFailed
        )
    }

    func testPendingImageReadyStateMapsToUploadAttachment() throws {
        let sourceImage = makeTestImage(size: CGSize(width: 400, height: 300))
        guard case .success(let processed) = CoachImagePipeline.process(image: sourceImage) else {
            return XCTFail("Expected pipeline success")
        }

        let pending = CoachPendingImageState.from(
            processed: processed,
            source: .library,
            originalEstimatedBytes: 900_000
        )
        let attachment = try XCTUnwrap(CoachMealImageUploadAttachment.from(pending: pending))

        XCTAssertEqual(attachment.uploadData, processed.uploadData)
        XCTAssertEqual(attachment.mimeType, processed.uploadMIMEType)
    }

    private func makeTestImage(size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.systemOrange.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}

private extension Result {
    var successValue: Success? {
        switch self {
        case .success(let value): return value
        case .failure: return nil
        }
    }
}
