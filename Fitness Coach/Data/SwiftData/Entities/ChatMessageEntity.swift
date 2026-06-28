//
//  ChatMessageEntity.swift
//  Fitness Coach
//
//  DORMANT — registered in `FitPilotModelContainer.schema` only.
//
//  Coach renders in-memory `ChatMessage` values (`CoachModel.messages`); nothing
//  persists to this table yet. Conversational history is not the source of truth
//  for food, water, weight, or workout logs.
//
//  TODO(migration): Wire Coach persistence or remove via versioned migration. See
//  `Docs/PersistenceCleanupNotes.md`.
//

import Foundation
import SwiftData

@Model
final class ChatMessageEntity {

    @Attribute(.unique) var id: UUID
    var roleRawValue: String
    var text: String
    var createdAt: Date
    var relatedDailyLogId: UUID?
    var relatedEntryId: UUID?

    init(
        id: UUID,
        roleRawValue: String,
        text: String,
        createdAt: Date,
        relatedDailyLogId: UUID?,
        relatedEntryId: UUID?
    ) {
        self.id = id
        self.roleRawValue = roleRawValue
        self.text = text
        self.createdAt = createdAt
        self.relatedDailyLogId = relatedDailyLogId
        self.relatedEntryId = relatedEntryId
    }
}
