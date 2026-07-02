//
//  ChatMessage.swift
//  Fitness Coach
//
//  FitPilot AI — Core app-facing model.
//
//  ChatMessage is conversational display state/history only. It is not the
//  source of truth for food, water, weight, or workout logs.
//

import Foundation

struct ChatMessage: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var role: ChatMessageRole
    var text: String
    var createdAt: Date
    var relatedDailyLogId: UUID?
    var relatedEntryId: UUID?
    /// Optional JPEG bytes for a user-sent meal photo shown in the conversation.
    var attachedImageJPEGData: Data?

    init(
        id: UUID,
        role: ChatMessageRole,
        text: String,
        createdAt: Date,
        relatedDailyLogId: UUID?,
        relatedEntryId: UUID?,
        attachedImageJPEGData: Data? = nil
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = createdAt
        self.relatedDailyLogId = relatedDailyLogId
        self.relatedEntryId = relatedEntryId
        self.attachedImageJPEGData = attachedImageJPEGData
    }

    var hasAttachedImage: Bool {
        guard let attachedImageJPEGData else { return false }
        return !attachedImageJPEGData.isEmpty
    }
}
