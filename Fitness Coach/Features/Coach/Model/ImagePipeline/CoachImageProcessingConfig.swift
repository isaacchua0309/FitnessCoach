//
//  CoachImageProcessingConfig.swift
//  Fitness Coach
//
//  Forma — Tunable limits for Coach image normalization and AI upload encoding.
//

import CoreGraphics
import Foundation

/// Pixel dimensions using integer counts (orientation-aware display size).
struct CoachImagePixelSize: Equatable, Sendable {
    let width: Int
    let height: Int

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }

    init(size: CGSize) {
        width = Int(size.width.rounded())
        height = Int(size.height.rounded())
    }

    var cgSize: CGSize {
        CGSize(width: width, height: height)
    }

    var longestEdge: Int {
        max(width, height)
    }
}

/// Describes which resize/quality step produced the final AI upload JPEG.
enum CoachImagePipelineCompressionStrategy: String, Equatable, Sendable, CaseIterable {
    /// Default longest side with initial JPEG quality.
    case initial
    /// Same dimensions with reduced JPEG quality.
    case reducedQuality
    /// Reduced longest side with reduced JPEG quality.
    case reducedDimensions
    /// Reduced longest side with minimum JPEG quality.
    case minimumQuality
}

/// One resize/quality attempt in the AI upload compression ladder.
struct CoachImageCompressionAttempt: Equatable, Sendable {
    let maxLongestSide: CGFloat
    let quality: CGFloat
    let strategy: CoachImagePipelineCompressionStrategy
}

struct CoachImageProcessingConfig: Equatable, Sendable {
    var uploadLongestSide: CGFloat
    var fallbackLongestSide: CGFloat
    var initialJPEGQuality: CGFloat
    var reducedJPEGQuality: CGFloat
    var minimumJPEGQuality: CGFloat
    var thumbnailMaxEdge: CGFloat
    var thumbnailJPEGQuality: CGFloat
    var maxUploadBytes: Int
    var uploadMIMEType: String

    init(
        uploadLongestSide: CGFloat,
        fallbackLongestSide: CGFloat,
        initialJPEGQuality: CGFloat,
        reducedJPEGQuality: CGFloat,
        minimumJPEGQuality: CGFloat,
        thumbnailMaxEdge: CGFloat,
        thumbnailJPEGQuality: CGFloat,
        maxUploadBytes: Int,
        uploadMIMEType: String
    ) {
        self.uploadLongestSide = uploadLongestSide
        self.fallbackLongestSide = fallbackLongestSide
        self.initialJPEGQuality = initialJPEGQuality
        self.reducedJPEGQuality = reducedJPEGQuality
        self.minimumJPEGQuality = minimumJPEGQuality
        self.thumbnailMaxEdge = thumbnailMaxEdge
        self.thumbnailJPEGQuality = thumbnailJPEGQuality
        self.maxUploadBytes = maxUploadBytes
        self.uploadMIMEType = uploadMIMEType
    }

    init(upload: CoachImageUploadConfig) {
        self.init(
            uploadLongestSide: upload.preferredLongestSide,
            fallbackLongestSide: upload.fallbackLongestSide,
            initialJPEGQuality: upload.preferredJPEGQuality,
            reducedJPEGQuality: upload.fallbackJPEGQuality,
            minimumJPEGQuality: upload.aggressiveJPEGQuality,
            thumbnailMaxEdge: upload.thumbnailLongestSide,
            thumbnailJPEGQuality: upload.thumbnailJPEGQuality,
            maxUploadBytes: upload.maxUploadBytes,
            uploadMIMEType: upload.mimeType
        )
    }

    static let `default` = CoachImageProcessingConfig(upload: .default)

    /// Ordered compression ladder required by the Coach image pipeline spec.
    var compressionAttempts: [CoachImageCompressionAttempt] {
        [
            CoachImageCompressionAttempt(
                maxLongestSide: uploadLongestSide,
                quality: initialJPEGQuality,
                strategy: .initial
            ),
            CoachImageCompressionAttempt(
                maxLongestSide: uploadLongestSide,
                quality: reducedJPEGQuality,
                strategy: .reducedQuality
            ),
            CoachImageCompressionAttempt(
                maxLongestSide: fallbackLongestSide,
                quality: reducedJPEGQuality,
                strategy: .reducedDimensions
            ),
            CoachImageCompressionAttempt(
                maxLongestSide: fallbackLongestSide,
                quality: minimumJPEGQuality,
                strategy: .minimumQuality
            )
        ]
    }
}
