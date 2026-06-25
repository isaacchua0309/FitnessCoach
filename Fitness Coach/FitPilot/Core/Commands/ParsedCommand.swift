//
//  ParsedCommand.swift
//  Fitness Coach
//
//  FitPilot AI — A successfully parsed local command.
//

import Foundation

enum ParsedCommandConfidence: String, Codable, Equatable, Sendable {
    case high
    case medium
    case low
}

struct ParsedCommand: Codable, Equatable, Sendable {
    let intent: CommandIntent
    let originalText: String
    let confidence: ParsedCommandConfidence
    let requiresConfirmation: Bool
    let reason: String?

    init(
        intent: CommandIntent,
        originalText: String,
        confidence: ParsedCommandConfidence = .high,
        requiresConfirmation: Bool = false,
        reason: String? = nil
    ) {
        self.intent = intent
        self.originalText = originalText
        self.confidence = confidence
        self.requiresConfirmation = requiresConfirmation
        self.reason = reason
    }
}
