//
//  ChatMessageEntity+Mapping.swift
//  Fitness Coach
//
//  Mapping for dormant `ChatMessageEntity`. See `Docs/PersistenceCleanupNotes.md`.
//

import Foundation

extension ChatMessageEntity {

    convenience init(model: ChatMessage) {
        self.init(
            id: model.id,
            roleRawValue: model.role.rawValue,
            text: model.text,
            createdAt: model.createdAt,
            relatedDailyLogId: model.relatedDailyLogId,
            relatedEntryId: model.relatedEntryId
        )
    }

    func toModel() -> ChatMessage {
        ChatMessage(
            id: id,
            role: ChatMessageRole(rawValue: roleRawValue) ?? .assistant,
            text: text,
            createdAt: createdAt,
            relatedDailyLogId: relatedDailyLogId,
            relatedEntryId: relatedEntryId
        )
    }
}
