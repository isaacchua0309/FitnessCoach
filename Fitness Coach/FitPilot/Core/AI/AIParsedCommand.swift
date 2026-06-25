//
//  AIParsedCommand.swift
//  Fitness Coach
//
//  FitPilot AI — Structured command parsed by the AI boundary.
//
//  This is an AI-produced intent. It is validated before any service executes
//  it. The AI layer never mutates app state.
//

import Foundation

enum AICommandIntent: String, Codable, Equatable, Sendable {
    case logFood
    case logWater
    case logWeight
    case logWorkout
    case startNewDay
    case mealAdvice
    case status
    case dailyReview
    case multiAction
    case unknown
}

struct AIParsedCommand: Codable, Equatable, Sendable {
    var originalText: String
    var intent: AICommandIntent
    var actions: [AICommandAction]
    var confidence: AIConfidence
    var requiresConfirmation: Bool
    var assistantMessage: String?
    var reasoningSummary: String?

    init(
        originalText: String,
        intent: AICommandIntent,
        actions: [AICommandAction] = [],
        confidence: AIConfidence,
        requiresConfirmation: Bool,
        assistantMessage: String? = nil,
        reasoningSummary: String? = nil
    ) {
        self.originalText = originalText
        self.intent = intent
        self.actions = actions
        self.confidence = confidence
        self.requiresConfirmation = requiresConfirmation
        self.assistantMessage = assistantMessage
        self.reasoningSummary = reasoningSummary
    }
}
