//
//  ChatMessage.swift
//  Fitness Coach
//
//  FitPilot AI — Core app-facing model.
//
//  ChatMessage is conversational display state/history only. It is not the
//  source of truth for food, water, weight, or workout logs.
//
//  Image attachments are kept in memory for the active Coach session. See
//  `CoachChatTranscriptStore` for the persistence boundary.
//

import Foundation

struct ChatMessage: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var role: ChatMessageRole
    var text: String
    var createdAt: Date
    var relatedDailyLogId: UUID?
    var relatedEntryId: UUID?
    /// Structured image attachment for meal-photo user messages.
    var imageAttachment: ChatMessageImageAttachment?
    /// Assistant ↔ user photo linkage for analysis results, including failures.
    var photoAnalysisLink: ChatMessagePhotoAnalysisLink?

    init(
        id: UUID = UUID(),
        role: ChatMessageRole,
        text: String,
        createdAt: Date = Date(),
        relatedDailyLogId: UUID? = nil,
        relatedEntryId: UUID? = nil,
        imageAttachment: ChatMessageImageAttachment? = nil,
        photoAnalysisLink: ChatMessagePhotoAnalysisLink? = nil
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = createdAt
        self.relatedDailyLogId = relatedDailyLogId
        self.relatedEntryId = relatedEntryId
        self.imageAttachment = imageAttachment
        self.photoAnalysisLink = photoAnalysisLink
    }

    var hasMealPhotoAttachment: Bool {
        imageAttachment?.kind == .mealPhoto
    }

    /// Full-resolution JPEG for analysis retry and expanded preview.
    var mealPhotoJPEG: Data? {
        imageAttachment?.imageJPEG
    }

    /// Backward-compatible failure metadata accessor.
    var mealPhotoAnalysisFailure: CoachMealPhotoAnalysisFailureInfo? {
        guard let link = photoAnalysisLink, link.isFailure else { return nil }
        return CoachMealPhotoAnalysisFailureInfo(relatedUserMessageID: link.relatedUserMessageID)
    }
}

extension ChatMessage {
    static func userMealPhoto(
        caption: String?,
        attachment: ChatMessageImageAttachment,
        createdAt: Date = Date()
    ) -> ChatMessage {
        ChatMessage(
            role: .user,
            text: caption ?? "",
            createdAt: createdAt,
            imageAttachment: attachment
        )
    }

    static func assistantPhotoAnalysisFailure(
        text: String,
        sessionID: UUID,
        relatedUserMessageID: UUID,
        createdAt: Date = Date()
    ) -> ChatMessage {
        ChatMessage(
            role: .assistant,
            text: text,
            createdAt: createdAt,
            photoAnalysisLink: ChatMessagePhotoAnalysisLink(
                sessionID: sessionID,
                relatedUserMessageID: relatedUserMessageID,
                kind: .failure
            )
        )
    }

    static func assistantPhotoAnalysisResult(
        text: String,
        sessionID: UUID,
        relatedUserMessageID: UUID,
        createdAt: Date = Date()
    ) -> ChatMessage {
        ChatMessage(
            role: .assistant,
            text: text,
            createdAt: createdAt,
            photoAnalysisLink: ChatMessagePhotoAnalysisLink(
                sessionID: sessionID,
                relatedUserMessageID: relatedUserMessageID,
                kind: .result
            )
        )
    }

    static func assistantPhotoClarification(
        text: String,
        sessionID: UUID,
        relatedUserMessageID: UUID,
        createdAt: Date = Date()
    ) -> ChatMessage {
        ChatMessage(
            role: .assistant,
            text: text,
            createdAt: createdAt,
            photoAnalysisLink: ChatMessagePhotoAnalysisLink(
                sessionID: sessionID,
                relatedUserMessageID: relatedUserMessageID,
                kind: .clarification
            )
        )
    }
}
