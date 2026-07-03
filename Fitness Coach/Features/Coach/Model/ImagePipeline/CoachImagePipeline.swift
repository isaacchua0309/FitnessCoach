//
//  CoachImagePipeline.swift
//  Fitness Coach
//
//  Forma — Dedicated Coach image processing: orientation, metadata stripping,
//  thumbnail generation, and gateway-sized AI upload encoding.
//

import UIKit

enum CoachImagePipeline {

    /// Processes a `UIImage` synchronously on the caller's thread.
    static func process(
        image: UIImage,
        config: CoachImageProcessingConfig = .default
    ) -> CoachImagePipelineResult {
        guard image.cgImage != nil else {
            return .failure(.invalidInput)
        }

        let originalPixelSize = CoachImagePipelineEncoding.displayPixelSize(of: image)

        guard let normalized = CoachImagePipelineEncoding.normalizeOrientation(image) else {
            return .failure(.encodingFailed)
        }

        guard let thumbnailData = CoachImagePipelineEncoding.encodeThumbnail(
            from: normalized,
            config: config
        ) else {
            return .failure(.encodingFailed)
        }

        guard let upload = CoachImagePipelineEncoding.encodeUploadPayload(
            from: normalized,
            config: config
        ) else {
            return .failure(.exceedsMaxSize(maxBytes: config.maxUploadBytes))
        }

        let processed = CoachProcessedImage(
            thumbnailData: thumbnailData,
            uploadData: upload.data,
            uploadMIMEType: config.uploadMIMEType,
            originalPixelSize: originalPixelSize,
            processedPixelSize: upload.processedPixelSize,
            finalByteSize: upload.data.count,
            compressionStrategy: upload.strategy
        )

        return .success(processed)
    }

    /// Runs CPU-heavy work off the main actor.
    static func processAsync(
        image: UIImage,
        config: CoachImageProcessingConfig = .default
    ) async -> CoachImagePipelineResult {
        await Task.detached(priority: .userInitiated) {
            process(image: image, config: config)
        }.value
    }

    /// Builds a composer/chat thumbnail from already-compressed upload JPEG bytes.
    static func makeThumbnailSync(
        from uploadJPEG: Data,
        config: CoachImageProcessingConfig = .default
    ) -> Data? {
        guard let image = UIImage(data: uploadJPEG),
              let normalized = CoachImagePipelineEncoding.normalizeOrientation(image) else {
            return nil
        }
        return CoachImagePipelineEncoding.encodeThumbnail(from: normalized, config: config)
    }
}
