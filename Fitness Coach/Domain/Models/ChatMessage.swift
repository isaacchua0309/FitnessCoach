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
    /// JPEG bytes for in-thread meal photo display and analysis retry.
    var mealPhotoJPEG: Data?
    /// When set on an assistant message, offers retry for the linked user photo message.
    var mealPhotoAnalysisFailure: CoachMealPhotoAnalysisFailureInfo?

    init(
        id: UUID = UUID(),
        role: ChatMessageRole,
        text: String,
        createdAt: Date = Date(),
        relatedDailyLogId: UUID? = nil,
        relatedEntryId: UUID? = nil,
        mealPhotoJPEG: Data? = nil,
        mealPhotoAnalysisFailure: CoachMealPhotoAnalysisFailureInfo? = nil
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = createdAt
        self.relatedDailyLogId = relatedDailyLogId
        self.relatedEntryId = relatedEntryId
        self.mealPhotoJPEG = mealPhotoJPEG
        self.mealPhotoAnalysisFailure = mealPhotoAnalysisFailure
    }
}
