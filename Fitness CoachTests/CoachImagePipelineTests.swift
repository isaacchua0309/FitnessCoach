//
//  CoachImagePipelineTests.swift
//  Fitness CoachTests
//
//  CoachImagePipeline geometry, compression ladder, and end-to-end processing.
//

import ImageIO
import UIKit
import XCTest
@testable import Fitness_Coach

final class CoachImagePipelineTests: XCTestCase {

    // MARK: - Compression ladder

    func testCompressionAttemptsFollowRequiredOrder() {
        let attempts = CoachImageProcessingConfig.default.compressionAttempts
        XCTAssertEqual(attempts.count, 4)
        XCTAssertEqual(attempts[0].strategy, .initial)
        XCTAssertEqual(attempts[0].maxLongestSide, 1_280)
        XCTAssertEqual(attempts[0].quality, 0.8, accuracy: 0.001)

        XCTAssertEqual(attempts[1].strategy, .reducedQuality)
        XCTAssertEqual(attempts[1].maxLongestSide, 1_280)
        XCTAssertEqual(attempts[1].quality, 0.7, accuracy: 0.001)

        XCTAssertEqual(attempts[2].strategy, .reducedDimensions)
        XCTAssertEqual(attempts[2].maxLongestSide, 1_024)
        XCTAssertEqual(attempts[2].quality, 0.7, accuracy: 0.001)

        XCTAssertEqual(attempts[3].strategy, .minimumQuality)
        XCTAssertEqual(attempts[3].maxLongestSide, 1_024)
        XCTAssertEqual(attempts[3].quality, 0.6, accuracy: 0.001)
    }

    func testEncodeUploadPayloadSelectsFirstFittingAttempt() {
        let image = Self.makeSolidImage(size: CGSize(width: 200, height: 150))
        guard let normalized = CoachImagePipelineEncoding.normalizeOrientation(image) else {
            return XCTFail("Expected normalized image")
        }

        let payload = CoachImagePipelineEncoding.encodeUploadPayload(
            from: normalized,
            config: .default
        )

        XCTAssertEqual(payload?.strategy, .initial)
        XCTAssertLessThanOrEqual(payload?.data.count ?? .max, CoachImageProcessingConfig.default.maxUploadBytes)
    }

    func testEncodeUploadPayloadFailsWhenEveryAttemptExceedsLimit() {
        let image = Self.makeSolidImage(size: CGSize(width: 200, height: 200))
        guard let normalized = CoachImagePipelineEncoding.normalizeOrientation(image) else {
            return XCTFail("Expected normalized image")
        }

        let strictConfig = CoachImageProcessingConfig(
            uploadLongestSide: 1_280,
            fallbackLongestSide: 1_024,
            initialJPEGQuality: 0.8,
            reducedJPEGQuality: 0.7,
            minimumJPEGQuality: 0.6,
            thumbnailMaxEdge: 128,
            thumbnailJPEGQuality: 0.75,
            maxUploadBytes: 32,
            uploadMIMEType: "image/jpeg"
        )

        XCTAssertNil(
            CoachImagePipelineEncoding.encodeUploadPayload(
                from: normalized,
                config: strictConfig
            )
        )
    }

    // MARK: - Orientation + metadata

    func testNormalizeOrientationProducesUprightPixels() {
        let source = Self.makeSolidImage(size: CGSize(width: 320, height: 180))
        guard let rotated = Self.applyOrientation(.right, to: source),
              let normalized = CoachImagePipelineEncoding.normalizeOrientation(rotated) else {
            return XCTFail("Expected normalized rotated image")
        }

        XCTAssertEqual(normalized.imageOrientation, .up)
        XCTAssertEqual(
            CoachImagePipelineEncoding.pixelSize(of: normalized),
            CoachImagePixelSize(width: 180, height: 320)
        )
    }

    func testNormalizeOrientationStripsJPEGMetadata() throws {
        let source = Self.makeSolidImage(size: CGSize(width: 120, height: 90))
        guard let normalized = CoachImagePipelineEncoding.normalizeOrientation(source),
              let jpeg = CoachImagePipelineEncoding.encodeJPEG(normalized, quality: 0.8) else {
            return XCTFail("Expected JPEG payload")
        }

        let properties = try XCTUnwrap(
            CGImageSourceCopyPropertiesAtIndex(
                CGImageSourceCreateWithData(jpeg as CFData, nil)!,
                0,
                nil
            ) as? [CFString: Any]
        )

        XCTAssertNil(properties[kCGImagePropertyGPSDictionary])
        XCTAssertNil(properties[kCGImagePropertyExifDictionary])
    }

    // MARK: - Resize

    func testResizeDoesNotUpscaleSmallImages() {
        let image = Self.makeSolidImage(size: CGSize(width: 400, height: 300))
        let resized = CoachImagePipelineEncoding.resize(image, maxLongestSide: 1_280)
        XCTAssertEqual(
            CoachImagePipelineEncoding.pixelSize(of: resized),
            CoachImagePixelSize(width: 400, height: 300)
        )
    }

    func testResizeLimitsLongestEdge() {
        let image = Self.makeSolidImage(size: CGSize(width: 2_560, height: 1_440))
        let resized = CoachImagePipelineEncoding.resize(image, maxLongestSide: 1_280)
        XCTAssertEqual(resized.pixelSize.longestEdge, 1_280)
        XCTAssertEqual(
            CoachImagePipelineEncoding.pixelSize(of: resized),
            CoachImagePixelSize(width: 1_280, height: 720)
        )
    }

    // MARK: - End-to-end pipeline

    func testThumbnailUsesConfiguredMaxEdge() {
        let image = Self.makeSolidImage(size: CGSize(width: 2_048, height: 1_536))
        guard let normalized = CoachImagePipelineEncoding.normalizeOrientation(image),
              let thumbnailData = CoachImagePipelineEncoding.encodeThumbnail(
                from: normalized,
                config: .default
              ),
              let thumbnail = UIImage(data: thumbnailData) else {
            return XCTFail("Expected thumbnail")
        }

        XCTAssertLessThanOrEqual(thumbnail.pixelSize.longestEdge, 128)
    }

    func testProcessReturnsStronglyTypedSuccessPayload() {
        let image = Self.makeSolidImage(size: CGSize(width: 640, height: 480))
        let result = CoachImagePipeline.process(image: image)

        guard case .success(let processed) = result else {
            return XCTFail("Expected success, got \(result)")
        }

        XCTAssertFalse(processed.thumbnailData.isEmpty)
        XCTAssertNotNil(processed.thumbnailUIImage)
        XCTAssertFalse(processed.uploadData.isEmpty)
        XCTAssertNotNil(processed.uploadUIImage)
        XCTAssertEqual(processed.uploadMIMEType, "image/jpeg")
        XCTAssertEqual(processed.originalPixelSize, CoachImagePixelSize(width: 640, height: 480))
        XCTAssertEqual(processed.finalByteSize, processed.uploadData.count)
        XCTAssertLessThanOrEqual(processed.finalByteSize, CoachImageProcessingConfig.default.maxUploadBytes)
        XCTAssertEqual(processed.compressionStrategy, .initial)
    }

    func testProcessLargePhotoFitsGatewayLimits() {
        let image = Self.makeLargeTestImage()
        let result = CoachImagePipeline.process(image: image)

        guard case .success(let processed) = result else {
            return XCTFail("Expected success, got \(result)")
        }

        XCTAssertTrue(AIGatewayPayloadLimits.fitsImagePayload(processed.uploadData))
        XCTAssertLessThanOrEqual(processed.processedPixelSize.longestEdge, 1_280)
    }

    func testProcessAsyncReturnsSameResultAsSync() async {
        let image = Self.makeSolidImage(size: CGSize(width: 512, height: 512))
        let sync = CoachImagePipeline.process(image: image)
        let async = await CoachImagePipeline.processAsync(image: image)
        XCTAssertEqual(sync, async)
    }

    func testProcessInvalidInputReturnsFailure() {
        let empty = UIImage()
        let result = CoachImagePipeline.process(image: empty)
        XCTAssertEqual(result, .failure(.invalidInput))
    }

    func testProcessExceedsMaxSizeReturnsTypedFailure() {
        let image = Self.makeSolidImage(size: CGSize(width: 256, height: 256))
        let config = CoachImageProcessingConfig(
            uploadLongestSide: 1_280,
            fallbackLongestSide: 1_024,
            initialJPEGQuality: 0.8,
            reducedJPEGQuality: 0.7,
            minimumJPEGQuality: 0.6,
            thumbnailMaxEdge: 128,
            thumbnailJPEGQuality: 0.75,
            maxUploadBytes: 16,
            uploadMIMEType: "image/jpeg"
        )

        let result = CoachImagePipeline.process(image: image, config: config)
        XCTAssertEqual(result, .failure(.exceedsMaxSize(maxBytes: 16)))
    }

    // MARK: - Fixtures

    private static func makeSolidImage(size: CGSize, color: UIColor = .systemTeal) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    private static func makeLargeTestImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 4_032, height: 3_024))
        return renderer.image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 4_032, height: 3_024))
            UIColor.systemPink.setFill()
            context.fill(CGRect(x: 400, y: 300, width: 2_800, height: 2_000))
        }
    }

    private static func applyOrientation(
        _ orientation: UIImage.Orientation,
        to image: UIImage
    ) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        return UIImage(cgImage: cgImage, scale: 1, orientation: orientation)
    }
}

private extension UIImage {
    var pixelSize: CoachImagePixelSize {
        CoachImagePipelineEncoding.pixelSize(of: self)
    }
}
