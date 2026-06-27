//
//  ChatMessageEntity.swift
//  Fitness Coach
//
//  FitPilot AI — SwiftData persistence entity.
//
//  ChatMessageEntity is conversational history only. It is not the source of
//  truth for food, water, weight, or workout logs.
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
