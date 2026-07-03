//
//  CoachImagePipelineEncoding.swift
//  Fitness Coach
//
//  Forma — Pure, unit-testable geometry and JPEG helpers for CoachImagePipeline.
//

import UIKit

enum CoachImagePipelineEncoding {

    // MARK: - Pixel geometry

    static func pixelSize(of image: UIImage) -> CoachImagePixelSize {
        if let cgImage = image.cgImage {
            return CoachImagePixelSize(width: cgImage.width, height: cgImage.height)
        }

        let scaled = CGSize(
            width: image.size.width * image.scale,
            height: image.size.height * image.scale
        )
        return CoachImagePixelSize(size: scaled)
    }

    /// Display-oriented pixel size after orientation normalization.
    static func displayPixelSize(of image: UIImage) -> CoachImagePixelSize {
        let raw = pixelSize(of: image)
        switch image.imageOrientation {
        case .left, .leftMirrored, .right, .rightMirrored:
            return CoachImagePixelSize(width: raw.height, height: raw.width)
        default:
            return raw
        }
    }

    // MARK: - Orientation + metadata stripping

    /// Redraws the image upright at scale 1, stripping EXIF and other metadata.
    static func normalizeOrientation(_ image: UIImage) -> UIImage? {
        guard image.cgImage != nil else { return nil }

        let outputSize = displayPixelSize(of: image)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: outputSize.cgSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: outputSize.cgSize))
        }
    }

    // MARK: - Resize + encode

    static func resize(_ image: UIImage, maxLongestSide: CGFloat) -> UIImage {
        let current = pixelSize(of: image)
        let longest = CGFloat(current.longestEdge)
        guard longest > maxLongestSide, longest > 0 else { return image }

        let scale = maxLongestSide / longest
        let targetSize = CGSize(
            width: CGFloat(current.width) * scale,
            height: CGFloat(current.height) * scale
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    static func encodeJPEG(_ image: UIImage, quality: CGFloat) -> Data? {
        image.jpegData(compressionQuality: quality)
    }

    // MARK: - Compression ladder

    struct EncodedUploadPayload: Equatable, Sendable {
        let data: Data
        let strategy: CoachImagePipelineCompressionStrategy
        let processedPixelSize: CoachImagePixelSize
    }

    static func encodeUploadPayload(
        from normalizedImage: UIImage,
        config: CoachImageProcessingConfig
    ) -> EncodedUploadPayload? {
        for attempt in config.compressionAttempts {
            let resized = resize(normalizedImage, maxLongestSide: attempt.maxLongestSide)
            guard let data = encodeJPEG(resized, quality: attempt.quality),
                  data.count <= config.maxUploadBytes else {
                continue
            }

            return EncodedUploadPayload(
                data: data,
                strategy: attempt.strategy,
                processedPixelSize: pixelSize(of: resized)
            )
        }
        return nil
    }

    static func encodeThumbnail(
        from normalizedImage: UIImage,
        config: CoachImageProcessingConfig
    ) -> Data? {
        let resized = resize(normalizedImage, maxLongestSide: config.thumbnailMaxEdge)
        return encodeJPEG(resized, quality: config.thumbnailJPEGQuality)
    }
}
