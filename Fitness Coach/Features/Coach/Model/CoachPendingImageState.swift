//
//  CoachPendingImageState.swift
//  Fitness Coach
//
//  Forma — Single source of truth for Coach composer meal-photo state.
//

import Foundation
import UIKit

enum CoachInputAttachmentSource: Equatable, Codable, Sendable {
    case camera
    case library
}

enum CoachPendingImageStatus: Equatable, Sendable {
    case processing
    case ready
    case failed
}

/// Composer meal-photo payload separating UI thumbnail, AI upload bytes, and lifecycle status.
struct CoachPendingImageState: Equatable, Identifiable, Sendable {
    let id: UUID
    var thumbnail: Data
    var uploadData: Data
    var mimeType: String
    var processedSize: CoachImagePixelSize
    var byteSize: Int
    var status: CoachPendingImageStatus
    var source: CoachInputAttachmentSource

    /// Original local selection metadata (not sent to AI).
    var originalPixelSize: CoachImagePixelSize?
    var originalEstimatedBytes: Int?
    var compressionStrategy: CoachImagePipelineCompressionStrategy?
    var localReferenceID: UUID?

    var isReady: Bool {
        status == .ready
    }

    var isProcessing: Bool {
        status == .processing
    }

    var isFailed: Bool {
        status == .failed
    }

    var isPipelineProcessedUpload: Bool {
        compressionStrategy != nil
    }

    var thumbnailUIImage: UIImage? {
        UIImage(data: thumbnail)
    }

    var uploadUIImage: UIImage? {
        UIImage(data: uploadData)
    }

    init(
        id: UUID = UUID(),
        thumbnail: Data,
        uploadData: Data,
        mimeType: String,
        processedSize: CoachImagePixelSize,
        byteSize: Int,
        status: CoachPendingImageStatus,
        source: CoachInputAttachmentSource,
        originalPixelSize: CoachImagePixelSize? = nil,
        originalEstimatedBytes: Int? = nil,
        compressionStrategy: CoachImagePipelineCompressionStrategy? = nil,
        localReferenceID: UUID? = nil
    ) {
        self.id = id
        self.thumbnail = thumbnail
        self.uploadData = uploadData
        self.mimeType = mimeType
        self.processedSize = processedSize
        self.byteSize = byteSize
        self.status = status
        self.source = source
        self.originalPixelSize = originalPixelSize
        self.originalEstimatedBytes = originalEstimatedBytes
        self.compressionStrategy = compressionStrategy
        self.localReferenceID = localReferenceID
    }

    static func from(
        processed: CoachProcessedImage,
        source: CoachInputAttachmentSource,
        originalEstimatedBytes: Int?,
        localReferenceID: UUID? = nil,
        id: UUID = UUID()
    ) -> CoachPendingImageState {
        CoachPendingImageState(
            id: id,
            thumbnail: processed.thumbnailData,
            uploadData: processed.uploadData,
            mimeType: processed.uploadMIMEType,
            processedSize: processed.processedPixelSize,
            byteSize: processed.finalByteSize,
            status: .ready,
            source: source,
            originalPixelSize: processed.originalPixelSize,
            originalEstimatedBytes: originalEstimatedBytes,
            compressionStrategy: processed.compressionStrategy,
            localReferenceID: localReferenceID
        )
    }

    static func processing(
        source: CoachInputAttachmentSource,
        preserving existing: CoachPendingImageState?
    ) -> CoachPendingImageState {
        if var existing {
            switch existing.status {
            case .ready:
                existing.status = .processing
                existing.source = source
                return existing
            case .failed, .processing:
                existing.status = .processing
                existing.source = source
                return existing
            }
        }

        return CoachPendingImageState(
            thumbnail: Data(),
            uploadData: Data(),
            mimeType: CoachImageUploadConfig.default.mimeType,
            processedSize: CoachImagePixelSize(width: 0, height: 0),
            byteSize: 0,
            status: .processing,
            source: source
        )
    }
}

extension CoachPendingImageState {

    mutating func markFailedPreservingReadyPayload() {
        guard status == .processing, byteSize > 0, !uploadData.isEmpty else {
            return
        }
        status = .ready
    }
}
