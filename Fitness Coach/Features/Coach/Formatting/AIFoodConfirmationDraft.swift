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
    var mealDraft: FoodLogDraft
    var confidence: AIConfidence
    var requiresConfirmation: Bool
    var sanityWarning: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        originalText: String,
        assistantMessage: String?,
        mealDraft: FoodLogDraft,
        confidence: AIConfidence,
        requiresConfirmation: Bool,
        sanityWarning: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.originalText = originalText
        self.assistantMessage = assistantMessage
        self.mealDraft = mealDraft
        self.confidence = confidence
        self.requiresConfirmation = requiresConfirmation
        self.sanityWarning = sanityWarning
        self.createdAt = createdAt
    }

    /// Legacy accessor for single-item flows and tests.
    var foodDrafts: [FoodDraft] {
        [FoodLogDraftMapper.toLegacyDraft(mealDraft)]
    }

    var primaryFoodDraft: FoodDraft? {
        foodDrafts.first
    }

    var primaryMealDraft: FoodLogDraft {
        mealDraft
    }
}
