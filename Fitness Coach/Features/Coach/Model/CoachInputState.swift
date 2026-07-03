//
//  CoachInputState.swift
//  Fitness Coach
//
//  Forma — Dedicated composer state for Coach text and image attachments.
//

import Foundation
import UIKit

// MARK: - Attachment

enum CoachInputAttachmentKind: Equatable, Codable, Sendable {
    case image
}

enum CoachInputAttachmentSource: Equatable, Codable, Sendable {
    case camera
    case library
}

struct CoachInputAttachmentProcessingMetadata: Equatable, Sendable {
    let originalPixelSize: CoachImagePixelSize
    let processedPixelSize: CoachImagePixelSize
    let originalEstimatedBytes: Int?
    let compressionStrategy: CoachImagePipelineCompressionStrategy
}

struct CoachInputAttachment: Equatable, Identifiable, Sendable {
    let id: UUID
    let kind: CoachInputAttachmentKind
    let imageData: Data
    let thumbnail: Data
    let source: CoachInputAttachmentSource
    let createdAt: Date
    let processingMetadata: CoachInputAttachmentProcessingMetadata?

    init(
        id: UUID = UUID(),
        kind: CoachInputAttachmentKind = .image,
        imageData: Data,
        thumbnail: Data,
        source: CoachInputAttachmentSource,
        createdAt: Date = Date(),
        processingMetadata: CoachInputAttachmentProcessingMetadata? = nil
    ) {
        self.id = id
        self.kind = kind
        self.imageData = imageData
        self.thumbnail = thumbnail
        self.source = source
        self.createdAt = createdAt
        self.processingMetadata = processingMetadata
    }

    var isPipelineProcessedUpload: Bool {
        processingMetadata != nil
    }

    var uiImage: UIImage? {
        UIImage(data: imageData)
    }

    var thumbnailImage: UIImage? {
        UIImage(data: thumbnail)
    }

    static func make(
        jpegData: Data,
        source: CoachInputAttachmentSource,
        id: UUID = UUID(),
        createdAt: Date = Date()
    ) async -> CoachInputAttachment? {
        guard let thumbnail = await CoachMealPhotoPipeline.makeThumbnailJPEG(from: jpegData) else {
            return nil
        }
        return CoachInputAttachment(
            id: id,
            kind: .image,
            imageData: jpegData,
            thumbnail: thumbnail,
            source: source,
            createdAt: createdAt
        )
    }
}

// MARK: - Composer error

enum CoachInputComposerError: Equatable, Sendable {
    case attachmentAlreadyPresent
    case preparationFailed(CoachMealPhotoError)

    var message: String {
        switch self {
        case .attachmentAlreadyPresent:
            return FormaProductCopy.Coach.removePhotoBeforeAddingAnother
        case .preparationFailed(let error):
            return CoachResponseBuilder.mealPhotoError(error)
        }
    }
}

// MARK: - Input state

struct CoachInputState: Equatable {
    var text: String
    var attachment: CoachInputAttachment?
    var isSending: Bool
    var error: CoachInputComposerError?

    static let empty = CoachInputState(
        text: "",
        attachment: nil,
        isSending: false,
        error: nil
    )

    var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canSend: Bool {
        !isSending && (!trimmedText.isEmpty || attachment != nil)
    }

    var canPickImage: Bool {
        !isSending && attachment == nil
    }

    mutating func updateText(_ newText: String) {
        text = newText
        if error == .attachmentAlreadyPresent {
            error = nil
        }
    }

    /// Stages an image when `canPickImage`; otherwise records `attachmentAlreadyPresent`.
    @discardableResult
    mutating func stagePreparedImage(
        jpegData: Data,
        thumbnail: Data,
        source: CoachInputAttachmentSource
    ) -> Bool {
        guard canPickImage else {
            error = .attachmentAlreadyPresent
            return false
        }
        attachment = CoachInputAttachment(
            kind: .image,
            imageData: jpegData,
            thumbnail: thumbnail,
            source: source
        )
        error = nil
        return true
    }

    /// Stages a `CoachImagePipeline` result when `canPickImage`; otherwise records `attachmentAlreadyPresent`.
    @discardableResult
    mutating func stageProcessedImage(
        _ processed: CoachProcessedImage,
        originalEstimatedBytes: Int?,
        source: CoachInputAttachmentSource
    ) -> Bool {
        guard canPickImage else {
            error = .attachmentAlreadyPresent
            return false
        }
        attachment = CoachInputAttachment(
            kind: .image,
            imageData: processed.uploadData,
            thumbnail: processed.thumbnailData,
            source: source,
            processingMetadata: CoachInputAttachmentProcessingMetadata(
                originalPixelSize: processed.originalPixelSize,
                processedPixelSize: processed.processedPixelSize,
                originalEstimatedBytes: originalEstimatedBytes,
                compressionStrategy: processed.compressionStrategy
            )
        )
        error = nil
        return true
    }

    mutating func removeAttachment() {
        attachment = nil
        error = nil
    }

    /// Freezes the current composer payload and clears editable fields for send.
    mutating func takeSendSnapshot() -> CoachInputSendSnapshot? {
        guard canSend else { return nil }

        let snapshot = CoachInputSendSnapshot(
            text: text,
            trimmedText: trimmedText,
            attachment: attachment
        )
        text = ""
        attachment = nil
        error = nil
        return snapshot
    }

    /// Restores composer fields after an outbound send aborts before a user message is created.
    mutating func restore(from snapshot: CoachInputSendSnapshot) {
        text = snapshot.text
        attachment = snapshot.attachment
        error = nil
    }

    mutating func clearAfterSuccessfulSend() {
        text = ""
        attachment = nil
        error = nil
    }

    mutating func setSending(_ sending: Bool) {
        isSending = sending
    }
}

// MARK: - Frozen outbound payload

struct CoachInputSendSnapshot: Equatable {
    let text: String
    let trimmedText: String
    let attachment: CoachInputAttachment?

    var sendPayload: CoachMealPhotoSendPayload {
        if let attachment {
            if trimmedText.isEmpty {
                return .imageOnly(jpegData: attachment.imageData)
            }
            return .textAndImage(text: trimmedText, jpegData: attachment.imageData)
        }
        return .textOnly(trimmedText)
    }
}
