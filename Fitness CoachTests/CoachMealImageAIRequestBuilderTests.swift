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

    func testRejectsInvalidContextSchemaVersion() throws {
        let attachment = try makeUploadAttachmentFromPipeline()
        var invalidContext = CoachContextPacketV2.test
        invalidContext.meta.schemaVersion = 1

        let result = CoachMealImageAIRequestBuilder.buildAnalysisRequest(
            attachment: attachment,
            context: invalidContext,
            message: "Lunch"
        )

        XCTAssertEqual(result.failureValue, .invalidContext)
    }

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

        XCTAssertEqual(
            CoachMealImageAIRequestBuilder.validate(attachment),
            .failure(.emptyUploadData)
        )
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

        XCTAssertEqual(
            CoachMealImageAIRequestBuilder.validate(attachment),
            .failure(.uploadExceedsMaxBytes(byteCount: maxBytes + 1, maxBytes: maxBytes))
        )
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

    var failureValue: Failure? {
        switch self {
        case .success: return nil
        case .failure(let error): return error
        }
    }
}

private func makeUploadAttachmentFromPipeline() throws -> CoachMealImageUploadAttachment {
    let sourceImage = UIGraphicsImageRenderer(size: CGSize(width: 24, height: 24)).image { context in
        UIColor.systemOrange.setFill()
        context.fill(CGRect(origin: .zero, size: CGSize(width: 24, height: 24)))
    }
    guard case .success(let processed) = CoachImagePipeline.process(image: sourceImage) else {
        throw NSError(domain: "CoachMealImageAIRequestBuilderTests", code: 1)
    }
    return CoachMealImageUploadAttachment.from(processed: processed)
}
