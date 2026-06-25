//
//  AIFoodConfirmationDraft.swift
//  Fitness Coach
//
//  FitPilot AI — Pending AI food estimate awaiting user confirmation.
//

import Foundation

struct AIFoodConfirmationDraft: Identifiable, Equatable {
    let id: UUID
    var originalText: String
    var assistantMessage: String?
    var foodDrafts: [FoodDraft]
    var confidence: AIConfidence
    var requiresConfirmation: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        originalText: String,
        assistantMessage: String?,
        foodDrafts: [FoodDraft],
        confidence: AIConfidence,
        requiresConfirmation: Bool,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.originalText = originalText
        self.assistantMessage = assistantMessage
        self.foodDrafts = foodDrafts
        self.confidence = confidence
        self.requiresConfirmation = requiresConfirmation
        self.createdAt = createdAt
    }

    var primaryFoodDraft: FoodDraft? {
        foodDrafts.first
    }

    static func from(command: AIParsedCommand, foodDraft: FoodDraft) -> AIFoodConfirmationDraft {
        AIFoodConfirmationDraft(
            originalText: command.originalText,
            assistantMessage: command.assistantMessage,
            foodDrafts: [foodDraft],
            confidence: command.confidence,
            requiresConfirmation: true
        )
    }
}
