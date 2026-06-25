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
}
