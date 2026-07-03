//
//  CoachChatTranscriptMessageEntity+Mapping.swift
//  Fitness Coach
//
//  Forma — SwiftData mapping for Coach chat transcript messages.
//

import Foundation

private enum CoachChatTranscriptStructuredContentCoding {
    static let encoder = JSONEncoder()
    static let decoder = JSONDecoder()

    static func encode(_ content: CoachStructuredMessageContent?) -> String? {
        guard let content else { return nil }
        guard let data = try? encoder.encode(content) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func decode(_ json: String?) -> CoachStructuredMessageContent? {
        guard let json,
              let data = json.data(using: .utf8),
              let content = try? decoder.decode(CoachStructuredMessageContent.self, from: data) else {
            return nil
        }
        return content
    }
}

extension CoachChatTranscriptMessageEntity {

    convenience init(model: ChatMessage, userId: String?, updatedAt: Date = Date()) {
        let imagePayload = Self.imagePersistencePayload(from: model.imageAttachment)
        let link = model.photoAnalysisLink

        self.init(
            id: model.id,
            userId: userId,
            roleRawValue: model.role.rawValue,
            text: model.text,
            createdAt: model.createdAt,
            relatedDailyLogId: model.relatedDailyLogId,
            relatedEntryId: model.relatedEntryId,
            hasImageAttachment: model.imageAttachment != nil,
            imageKindRaw: imagePayload.kindRaw,
            imageSourceRaw: imagePayload.sourceRaw,
            thumbnailJPEG: imagePayload.thumbnailJPEG,
            fullImageJPEG: imagePayload.fullImageJPEG,
            originalImageByteSize: imagePayload.originalImageByteSize,
            photoSessionID: link?.sessionID,
            relatedUserMessageID: link?.relatedUserMessageID,
            photoAnalysisLinkKindRaw: link?.kind.rawValue,
            structuredContentJSON: CoachChatTranscriptStructuredContentCoding.encode(model.structuredContent),
            updatedAt: updatedAt
        )
    }

    func update(from model: ChatMessage, updatedAt: Date = Date()) {
        let imagePayload = Self.imagePersistencePayload(from: model.imageAttachment)
        let link = model.photoAnalysisLink

        roleRawValue = model.role.rawValue
        text = model.text
        createdAt = model.createdAt
        relatedDailyLogId = model.relatedDailyLogId
        relatedEntryId = model.relatedEntryId
        hasImageAttachment = model.imageAttachment != nil
        imageKindRaw = imagePayload.kindRaw
        imageSourceRaw = imagePayload.sourceRaw
        thumbnailJPEG = imagePayload.thumbnailJPEG
        fullImageJPEG = imagePayload.fullImageJPEG
        originalImageByteSize = imagePayload.originalImageByteSize
        photoSessionID = link?.sessionID
        relatedUserMessageID = link?.relatedUserMessageID
        photoAnalysisLinkKindRaw = link?.kind.rawValue
        structuredContentJSON = CoachChatTranscriptStructuredContentCoding.encode(model.structuredContent)
        self.updatedAt = updatedAt
    }

    func toModel() -> ChatMessage {
        ChatMessage(
            id: id,
            role: ChatMessageRole(rawValue: roleRawValue) ?? .assistant,
            text: text,
            createdAt: createdAt,
            relatedDailyLogId: relatedDailyLogId,
            relatedEntryId: relatedEntryId,
            imageAttachment: Self.imageAttachment(from: self),
            photoAnalysisLink: Self.photoAnalysisLink(from: self),
            structuredContent: CoachChatTranscriptStructuredContentCoding.decode(structuredContentJSON)
        )
    }

    // MARK: - Image persistence

    private struct ImagePersistencePayload {
        var kindRaw: String?
        var sourceRaw: String?
        var thumbnailJPEG: Data?
        var fullImageJPEG: Data?
        var originalImageByteSize: Int?
    }

    private static func imagePersistencePayload(
        from attachment: ChatMessageImageAttachment?
    ) -> ImagePersistencePayload {
        guard let attachment else {
            return ImagePersistencePayload(
                kindRaw: nil,
                sourceRaw: nil,
                thumbnailJPEG: nil,
                fullImageJPEG: nil,
                originalImageByteSize: nil
            )
        }

        let originalSize = attachment.imageJPEG.count
        let persistFullImage = originalSize <= CoachChatTranscriptRetentionPolicy.maxPersistedFullImageBytes

        return ImagePersistencePayload(
            kindRaw: attachment.kind.rawValue,
            sourceRaw: Self.sourceRawValue(attachment.source),
            thumbnailJPEG: attachment.thumbnailJPEG,
            fullImageJPEG: persistFullImage ? attachment.imageJPEG : nil,
            originalImageByteSize: originalSize
        )
    }

    private static func imageAttachment(from entity: CoachChatTranscriptMessageEntity) -> ChatMessageImageAttachment? {
        guard entity.hasImageAttachment else { return nil }

        let thumbnail = entity.thumbnailJPEG ?? Data()
        let displayJPEG = entity.fullImageJPEG ?? entity.thumbnailJPEG ?? Data()
        guard !displayJPEG.isEmpty || !thumbnail.isEmpty else { return nil }

        let kind = ChatMessageAttachmentKind(rawValue: entity.imageKindRaw ?? "") ?? .mealPhoto
        let source = Self.attachmentSource(from: entity.imageSourceRaw)

        return ChatMessageImageAttachment(
            kind: kind,
            imageJPEG: displayJPEG,
            thumbnailJPEG: thumbnail.isEmpty ? displayJPEG : thumbnail,
            source: source
        )
    }

    private static func photoAnalysisLink(
        from entity: CoachChatTranscriptMessageEntity
    ) -> ChatMessagePhotoAnalysisLink? {
        guard let sessionID = entity.photoSessionID,
              let relatedUserMessageID = entity.relatedUserMessageID,
              let kindRaw = entity.photoAnalysisLinkKindRaw,
              let kind = ChatMessagePhotoAnalysisLinkKind(rawValue: kindRaw) else {
            return nil
        }

        return ChatMessagePhotoAnalysisLink(
            sessionID: sessionID,
            relatedUserMessageID: relatedUserMessageID,
            kind: kind
        )
    }

    private static func sourceRawValue(_ source: CoachInputAttachmentSource?) -> String? {
        switch source {
        case .camera: return "camera"
        case .library: return "library"
        case .none: return nil
        }
    }

    private static func attachmentSource(from raw: String?) -> CoachInputAttachmentSource? {
        switch raw {
        case "camera": return .camera
        case "library": return .library
        default: return nil
        }
    }
}
