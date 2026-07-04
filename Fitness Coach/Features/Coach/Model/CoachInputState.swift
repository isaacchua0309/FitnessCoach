//
//  CoachInputState.swift
//  Fitness Coach
//
//  Forma — Dedicated composer state for Coach text and pending meal photos.
//

import Foundation

struct CoachInputState: Equatable {
    var text: String
    var pendingImage: CoachPendingImageState?
    var imageError: CoachMealPhotoError?
    var isSending: Bool

    static let empty = CoachInputState(
        text: "",
        pendingImage: nil,
        imageError: nil,
        isSending: false
    )

    var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var hasReadyPendingImage: Bool {
        pendingImage?.isReady == true
    }

    var isImageProcessing: Bool {
        pendingImage?.isProcessing == true
    }

    var canSend: Bool {
        !isSending && (!trimmedText.isEmpty || hasReadyPendingImage)
    }

    var canStartImageSelection: Bool {
        !isSending && !isImageProcessing
    }

    var imageErrorMessage: String? {
        imageError.map { CoachResponseBuilder.mealPhotoError($0) }
    }

    var imageErrorSupportsRetry: Bool {
        imageError?.supportsComposerRetry == true
    }

    mutating func updateText(_ newText: String) {
        text = newText
    }

    mutating func beginProcessingNewSelection(source: CoachInputAttachmentSource) {
        imageError = nil
        pendingImage = CoachPendingImageState.processing(
            source: source,
            preserving: pendingImage
        )
    }

    @discardableResult
    mutating func applyProcessedImage(
        _ processed: CoachProcessedImage,
        source: CoachInputAttachmentSource,
        originalEstimatedBytes: Int?,
        localReferenceID: UUID? = nil
    ) -> Bool {
        imageError = nil
        pendingImage = CoachPendingImageState.from(
            processed: processed,
            source: source,
            originalEstimatedBytes: originalEstimatedBytes,
            localReferenceID: localReferenceID
        )
        return true
    }

    mutating func failImageProcessing(_ error: CoachMealPhotoError) {
        imageError = error
        if var current = pendingImage {
            if current.markFailedPreservingReadyPayloadIfPossible() {
                pendingImage = current
            } else {
                current.status = .failed
                pendingImage = current
            }
        }
    }

    mutating func clearPendingImage() {
        pendingImage = nil
        imageError = nil
    }

    mutating func clearImageError() {
        imageError = nil
    }

    /// Freezes the current composer payload and clears editable fields for send.
    mutating func takeSendSnapshot() -> CoachInputSendSnapshot? {
        guard canSend else { return nil }

        let snapshot = CoachInputSendSnapshot(
            text: text,
            trimmedText: trimmedText,
            pendingImage: hasReadyPendingImage ? pendingImage : nil
        )
        text = ""
        pendingImage = nil
        imageError = nil
        return snapshot
    }

    /// Restores composer fields after an outbound send aborts before a user message is created.
    mutating func restore(from snapshot: CoachInputSendSnapshot) {
        text = snapshot.text
        pendingImage = snapshot.pendingImage
        imageError = nil
    }

    mutating func setSending(_ sending: Bool) {
        isSending = sending
    }
}

private extension CoachPendingImageState {
    mutating func markFailedPreservingReadyPayloadIfPossible() -> Bool {
        guard status == .processing, byteSize > 0, !uploadData.isEmpty else {
            return false
        }
        status = .ready
        return true
    }
}

// MARK: - Frozen outbound payload

struct CoachInputSendSnapshot: Equatable {
    let text: String
    let trimmedText: String
    let pendingImage: CoachPendingImageState?

    var sendPayload: CoachMealPhotoSendPayload {
        if let pendingImage {
            if trimmedText.isEmpty {
                return .imageOnly(jpegData: pendingImage.uploadData)
            }
            return .textAndImage(text: trimmedText, jpegData: pendingImage.uploadData)
        }
        return .textOnly(trimmedText)
    }
}
