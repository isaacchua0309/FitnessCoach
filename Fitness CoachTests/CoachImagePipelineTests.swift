//
//  CoachImagePipelineTests.swift
//  Fitness CoachTests
//
//  CoachImagePipeline geometry, compression ladder, and end-to-end processing.
//

import ImageIO
import UIKit
import UniformTypeIdentifiers
import XCTest
@testable import Fitness_Coach

final class CoachImagePipelineTests: XCTestCase {

    // MARK: - 1. Large 48MP-style image

    func testLarge48MegapixelStyleImageCompressesUnderMaxUploadBytes() {
        let image = Self.make48MegapixelStyleImage()
        let result = CoachImagePipeline.process(image: image)

        guard case .success(let processed) = result else {
            return XCTFail("Expected success, got \(result)")
        }

        XCTAssertLessThanOrEqual(
            processed.finalByteSize,
            CoachImageUploadConfig.default.maxUploadBytes
        )
        XCTAssertTrue(AIGatewayPayloadLimits.fitsImagePayload(processed.uploadData))
    }

    // MARK: - 2. Output longest side ≤ 1280 unless fallback

    func testOutputLongestSideIs1280OrLowerUnlessFallbackIsUsed() {
        let image = Self.makeNoisyImage(size: CGSize(width: 3_840, height: 2_160))
        guard case .success(let processed) = CoachImagePipeline.process(image: image) else {
            return XCTFail("Expected pipeline success")
        }

        let preferredEdge = Int(CoachImageUploadConfig.default.preferredLongestSide)
        let fallbackEdge = Int(CoachImageUploadConfig.default.fallbackLongestSide)

        switch processed.compressionStrategy {
        case .initial, .reducedQuality:
            XCTAssertLessThanOrEqual(processed.processedPixelSize.longestEdge, preferredEdge)
        case .reducedDimensions, .minimumQuality:
            XCTAssertLessThanOrEqual(processed.processedPixelSize.longestEdge, fallbackEdge)
        }
    }

    // MARK: - 3. Fallback to 1024 px

    func testFallbackTo1024PixelLongestSideWorks() throws {
        let image = Self.makeNoisyImage(size: CGSize(width: 1_600, height: 1_200))
        guard let normalized = CoachImagePipelineEncoding.normalizeOrientation(image) else {
            return XCTFail("Expected normalized image")
        }

        let resized1280 = CoachImagePipelineEncoding.resize(
            normalized,
            maxLongestSide: CoachImageUploadConfig.default.preferredLongestSide
        )
        let resized1024 = CoachImagePipelineEncoding.resize(
            normalized,
            maxLongestSide: CoachImageUploadConfig.default.fallbackLongestSide
        )
        let bytes1280 = try XCTUnwrap(
            CoachImagePipelineEncoding.encodeJPEG(
                resized1280,
                quality: CoachImageUploadConfig.default.fallbackJPEGQuality
            )
        )
        let bytes1024 = try XCTUnwrap(
            CoachImagePipelineEncoding.encodeJPEG(
                resized1024,
                quality: CoachImageUploadConfig.default.fallbackJPEGQuality
            )
        )

        XCTAssertGreaterThan(bytes1280.count, bytes1024.count)

        let maxBytes = bytes1280.count - 1
        XCTAssertLessThanOrEqual(bytes1024.count, maxBytes, "Test precondition: 1024px payload must fit under limit")

        let config = Self.processingConfig(maxUploadBytes: maxBytes)
        guard case .success(let processed) = CoachImagePipeline.process(image: image, config: config) else {
            return XCTFail("Expected 1024px dimension fallback")
        }

        XCTAssertEqual(processed.compressionStrategy, .reducedDimensions)
        XCTAssertEqual(
            processed.processedPixelSize.longestEdge,
            Int(CoachImageUploadConfig.default.fallbackLongestSide)
        )
    }

    // MARK: - 4. JPEG quality fallback

    func testJPEGQualityFallbackWorks() throws {
        let image = Self.makeNoisyImage(size: CGSize(width: 1_280, height: 960))
        guard let normalized = CoachImagePipelineEncoding.normalizeOrientation(image) else {
            return XCTFail("Expected normalized image")
        }

        let resized = CoachImagePipelineEncoding.resize(
            normalized,
            maxLongestSide: CoachImageUploadConfig.default.preferredLongestSide
        )
        let preferredQualityBytes = try XCTUnwrap(
            CoachImagePipelineEncoding.encodeJPEG(
                resized,
                quality: CoachImageUploadConfig.default.preferredJPEGQuality
            )
        )
        let fallbackQualityBytes = try XCTUnwrap(
            CoachImagePipelineEncoding.encodeJPEG(
                resized,
                quality: CoachImageUploadConfig.default.fallbackJPEGQuality
            )
        )

        XCTAssertGreaterThan(preferredQualityBytes.count, fallbackQualityBytes.count)

        let maxBytes = preferredQualityBytes.count - 1
        XCTAssertLessThanOrEqual(fallbackQualityBytes.count, maxBytes)

        let config = Self.processingConfig(maxUploadBytes: maxBytes)
        guard case .success(let processed) = CoachImagePipeline.process(image: image, config: config) else {
            return XCTFail("Expected reduced-quality fallback")
        }

        XCTAssertEqual(processed.compressionStrategy, .reducedQuality)
        XCTAssertEqual(
            processed.processedPixelSize.longestEdge,
            Int(CoachImageUploadConfig.default.preferredLongestSide)
        )
    }

    // MARK: - 5. Thumbnail generation

    func testThumbnailIsGeneratedFromPipelineOutput() {
        let image = Self.makeSolidImage(size: CGSize(width: 2_048, height: 1_536))
        guard case .success(let processed) = CoachImagePipeline.process(image: image) else {
            return XCTFail("Expected pipeline success")
        }

        XCTAssertFalse(processed.thumbnailData.isEmpty)
        XCTAssertNotEqual(processed.thumbnailData, processed.uploadData)

        guard let thumbnail = UIImage(data: processed.thumbnailData) else {
            return XCTFail("Expected decodable thumbnail")
        }

        XCTAssertLessThanOrEqual(
            thumbnail.pixelSize.longestEdge,
            Int(CoachImageUploadConfig.default.thumbnailLongestSide)
        )
    }

    // MARK: - 6. Metadata stripping

    func testEXIFAndLocationMetadataAreNotPreservedInPipelineOutput() throws {
        let source = try Self.makeJPEGWithGPSMetadata(size: CGSize(width: 640, height: 480))
        guard case .success(let processed) = CoachImagePipeline.process(image: source) else {
            return XCTFail("Expected pipeline success")
        }

        for label in ["upload", "thumbnail"] {
            let data = label == "upload" ? processed.uploadData : processed.thumbnailData
            let properties = try Self.jpegProperties(data)
            XCTAssertNil(properties[kCGImagePropertyGPSDictionary], "\(label) must not retain GPS metadata")
            XCTAssertNil(properties[kCGImagePropertyExifDictionary], "\(label) must not retain EXIF metadata")
        }
    }

    // MARK: - 7. Invalid input

    func testInvalidImageReturnsCleanFailure() {
        XCTAssertEqual(CoachImagePipeline.process(image: UIImage()), .failure(.invalidInput))

        let emptyData = Data()
        XCTAssertNil(UIImage(data: emptyData))
        XCTAssertEqual(CoachImagePipeline.process(image: UIImage()), .failure(.invalidInput))
    }

    // MARK: - 8–10. Pending image lifecycle (pipeline-produced payloads)

    func testRemovingPendingImageClearsUploadData() throws {
        var state = CoachInputState.empty
        let processed = try XCTUnwrap(processTestImage(size: CGSize(width: 720, height: 540)))

        XCTAssertTrue(
            state.applyProcessedImage(processed, source: .library, originalEstimatedBytes: 1_200_000)
        )
        XCTAssertFalse(state.pendingImage?.uploadData.isEmpty == true)
        XCTAssertFalse(state.pendingImage?.thumbnail.isEmpty == true)

        state.clearPendingImage()

        XCTAssertNil(state.pendingImage)
        XCTAssertNil(state.pendingImage?.uploadData)
        XCTAssertNil(state.pendingImage?.thumbnail)
    }

    func testFailedSendKeepsPendingImageForRetry() throws {
        var state = CoachInputState.empty
        let processed = try XCTUnwrap(processTestImage(size: CGSize(width: 640, height: 480)))
        XCTAssertTrue(
            state.applyProcessedImage(processed, source: .camera, originalEstimatedBytes: 900_000)
        )

        let snapshot = try XCTUnwrap(state.takeSendSnapshot())
        XCTAssertNil(state.pendingImage)

        state.restore(from: snapshot)

        XCTAssertEqual(state.pendingImage?.uploadData, processed.uploadData)
        XCTAssertEqual(state.pendingImage?.thumbnail, processed.thumbnailData)
        XCTAssertEqual(state.pendingImage?.source, .camera)
        XCTAssertTrue(state.canSend)
    }

    func testSuccessfulSendClearsPendingImage() throws {
        var state = CoachInputState.empty
        let processed = try XCTUnwrap(processTestImage(size: CGSize(width: 512, height: 384)))
        state.updateText("Lunch")
        XCTAssertTrue(
            state.applyProcessedImage(processed, source: .library, originalEstimatedBytes: 800_000)
        )

        let snapshot = try XCTUnwrap(state.takeSendSnapshot())

        XCTAssertNil(state.pendingImage)
        XCTAssertNil(state.imageError)
        XCTAssertEqual(snapshot.pendingImage?.uploadData, processed.uploadData)
        XCTAssertFalse(state.canSend)
    }

    // MARK: - Compression ladder order

    func testCompressionAttemptsFollowRequiredOrder() {
        let upload = CoachImageUploadConfig.default
        let attempts = CoachImageProcessingConfig.default.compressionAttempts
        XCTAssertEqual(attempts.count, 4)
        XCTAssertEqual(attempts[0].strategy, .initial)
        XCTAssertEqual(attempts[0].maxLongestSide, upload.preferredLongestSide)
        XCTAssertEqual(attempts[0].quality, upload.preferredJPEGQuality, accuracy: 0.001)

        XCTAssertEqual(attempts[1].strategy, .reducedQuality)
        XCTAssertEqual(attempts[1].maxLongestSide, upload.preferredLongestSide)
        XCTAssertEqual(attempts[1].quality, upload.fallbackJPEGQuality, accuracy: 0.001)

        XCTAssertEqual(attempts[2].strategy, .reducedDimensions)
        XCTAssertEqual(attempts[2].maxLongestSide, upload.fallbackLongestSide)
        XCTAssertEqual(attempts[2].quality, upload.fallbackJPEGQuality, accuracy: 0.001)

        XCTAssertEqual(attempts[3].strategy, .minimumQuality)
        XCTAssertEqual(attempts[3].maxLongestSide, upload.fallbackLongestSide)
        XCTAssertEqual(attempts[3].quality, upload.aggressiveJPEGQuality, accuracy: 0.001)
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

        let strictConfig = Self.processingConfig(maxUploadBytes: 32)

        XCTAssertNil(
            CoachImagePipelineEncoding.encodeUploadPayload(
                from: normalized,
                config: strictConfig
            )
        )
    }

    // MARK: - Orientation

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

        let properties = try Self.jpegProperties(jpeg)
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
        let upload = CoachImageUploadConfig.default
        let image = Self.makeSolidImage(size: CGSize(width: 2_560, height: 1_440))
        let resized = CoachImagePipelineEncoding.resize(image, maxLongestSide: upload.preferredLongestSide)
        XCTAssertEqual(resized.pixelSize.longestEdge, Int(upload.preferredLongestSide))
        XCTAssertEqual(
            CoachImagePipelineEncoding.pixelSize(of: resized),
            CoachImagePixelSize(width: Int(upload.preferredLongestSide), height: 720)
        )
    }

    // MARK: - End-to-end pipeline

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
        XCTAssertEqual(processed.uploadMIMEType, CoachImageUploadConfig.default.mimeType)
        XCTAssertEqual(processed.originalPixelSize, CoachImagePixelSize(width: 640, height: 480))
        XCTAssertEqual(processed.finalByteSize, processed.uploadData.count)
        XCTAssertLessThanOrEqual(processed.finalByteSize, CoachImageProcessingConfig.default.maxUploadBytes)
        XCTAssertEqual(processed.compressionStrategy, .initial)
    }

    func testProcessAsyncReturnsSameResultAsSync() async {
        let image = Self.makeSolidImage(size: CGSize(width: 512, height: 512))
        let sync = CoachImagePipeline.process(image: image)
        let async = await CoachImagePipeline.processAsync(image: image)
        XCTAssertEqual(sync, async)
    }

    func testProcessExceedsMaxSizeReturnsTypedFailure() {
        let image = Self.makeSolidImage(size: CGSize(width: 256, height: 256))
        let config = Self.processingConfig(maxUploadBytes: 16)

        let result = CoachImagePipeline.process(image: image, config: config)
        XCTAssertEqual(result, .failure(.exceedsMaxSize(maxBytes: 16)))
    }

    // MARK: - Helpers

    private func processTestImage(size: CGSize) -> CoachProcessedImage? {
        guard case .success(let processed) = CoachImagePipeline.process(
            image: Self.makeSolidImage(size: size)
        ) else {
            return nil
        }
        return processed
    }

    private static func processingConfig(maxUploadBytes: Int) -> CoachImageProcessingConfig {
        let upload = CoachImageUploadConfig.default
        return CoachImageProcessingConfig(
            upload: CoachImageUploadConfig(
                maxUploadBytes: maxUploadBytes,
                preferredLongestSide: upload.preferredLongestSide,
                fallbackLongestSide: upload.fallbackLongestSide,
                thumbnailLongestSide: upload.thumbnailLongestSide,
                preferredJPEGQuality: upload.preferredJPEGQuality,
                fallbackJPEGQuality: upload.fallbackJPEGQuality,
                aggressiveJPEGQuality: upload.aggressiveJPEGQuality,
                mimeType: upload.mimeType,
                thumbnailJPEGQuality: upload.thumbnailJPEGQuality,
                legacyUploadLongestSides: upload.legacyUploadLongestSides,
                legacyJPEGQualities: upload.legacyJPEGQualities
            )
        )
    }

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

    /// High-entropy image that produces larger JPEGs at the same dimensions (for fallback tests).
    private static func makeNoisyImage(size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            let block = 8
            for x in stride(from: 0, to: Int(size.width), by: block) {
                for y in stride(from: 0, to: Int(size.height), by: block) {
                    let color = UIColor(
                        hue: CGFloat((x ^ y) % 256) / 255.0,
                        saturation: 0.85,
                        brightness: CGFloat((x &* 31 &+ y) % 256) / 255.0,
                        alpha: 1
                    )
                    color.setFill()
                    context.fill(CGRect(x: x, y: y, width: block, height: block))
                }
            }
        }
    }

    /// ~48.7 MP (8064×6048), typical modern iPhone main-camera proportions.
    private static func make48MegapixelStyleImage() -> UIImage {
        makeNoisyImage(size: CGSize(width: 8_064, height: 6_048))
    }

    private static func makeJPEGWithGPSMetadata(size: CGSize) throws -> UIImage {
        let base = makeSolidImage(size: size)
        guard let cgImage = base.cgImage else {
            throw XCTSkip("Could not create base CGImage")
        }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            throw XCTSkip("Could not create image destination")
        }

        let gps: [CFString: Any] = [
            kCGImagePropertyGPSLatitude: 37.7749,
            kCGImagePropertyGPSLatitudeRef: "N",
            kCGImagePropertyGPSLongitude: -122.4194,
            kCGImagePropertyGPSLongitudeRef: "W"
        ]
        let properties: [CFString: Any] = [
            kCGImagePropertyGPSDictionary: gps,
            kCGImagePropertyExifDictionary: [
                kCGImagePropertyExifUserComment: "coach-pipeline-test"
            ]
        ]

        CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination),
              let image = UIImage(data: data as Data) else {
            throw XCTSkip("Could not finalize metadata-rich JPEG")
        }
        return image
    }

    private static func jpegProperties(_ data: Data) throws -> [CFString: Any] {
        let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        return try XCTUnwrap(
            CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        )
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
