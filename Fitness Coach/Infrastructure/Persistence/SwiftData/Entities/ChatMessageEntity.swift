//
//  ChatMessageEntity.swift
//  Fitness Coach
//
//  V1 MIGRATION ONLY — listed in `FormaSchemaV1` for lightweight migration to v2.
//  Removed from active `FormaSchemaV2` schema. Coach keeps messages in memory.
//  See `Docs/PersistenceCleanupNotes.md`.
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
