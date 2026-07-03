//
//  ChatMessageImageAttachment.swift
//  Fitness Coach
//
//  Forma — Image attachment metadata for Coach chat transcript messages.
//

import Foundation

enum ChatMessageAttachmentKind: String, Codable, Sendable, Equatable {
    case mealPhoto
}

/// Session-scoped image payload stored on `ChatMessage` for in-thread rendering and retry.
struct ChatMessageImageAttachment: Codable, Equatable, Sendable {
    var kind: ChatMessageAttachmentKind
    var imageJPEG: Data
    var thumbnailJPEG: Data
    var source: CoachInputAttachmentSource?

    init(
        kind: ChatMessageAttachmentKind = .mealPhoto,
        imageJPEG: Data,
        thumbnailJPEG: Data,
        source: CoachInputAttachmentSource? = nil
    ) {
        self.kind = kind
        self.imageJPEG = imageJPEG
        self.thumbnailJPEG = thumbnailJPEG
        self.source = source
    }

    static func fromPendingImage(_ pendingImage: CoachPendingImageState) -> ChatMessageImageAttachment {
        ChatMessageImageAttachment(
            imageJPEG: pendingImage.uploadData,
            thumbnailJPEG: pendingImage.thumbnail,
            source: pendingImage.source
        )
    }

    static func fromJPEG(
        _ imageJPEG: Data,
        source: CoachInputAttachmentSource? = nil
    ) -> ChatMessageImageAttachment? {
        guard let thumbnailJPEG = CoachMealPhotoPipeline.makeThumbnailJPEGSync(from: imageJPEG) else {
            return nil
        }
        return ChatMessageImageAttachment(
            imageJPEG: imageJPEG,
            thumbnailJPEG: thumbnailJPEG,
            source: source
        )
    }
}

/// Links an assistant message to the user photo message it analyzes or responds to.
enum ChatMessagePhotoAnalysisLinkKind: String, Codable, Equatable, Sendable {
    case result
    case failure
    case clarification
}

struct ChatMessagePhotoAnalysisLink: Equatable, Codable, Sendable {
    let sessionID: UUID
    let relatedUserMessageID: UUID
    var kind: ChatMessagePhotoAnalysisLinkKind

    var isFailure: Bool { kind == .failure }
}

/// Backward-compatible view of failure linkage on assistant messages.
struct CoachMealPhotoAnalysisFailureInfo: Equatable, Codable, Sendable {
    let relatedUserMessageID: UUID
}
