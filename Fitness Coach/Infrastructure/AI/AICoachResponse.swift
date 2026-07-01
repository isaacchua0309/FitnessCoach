//
//  AICoachResponse.swift
//  Fitness Coach
//
//  FitPilot AI — Free-form coaching text returned by the AI boundary.
//
//  Used for meal advice and daily review text. This is display text only; it is
//  never treated as final arithmetic or persisted state.
//

import Foundation

struct AICoachResponse: Codable, Equatable, Sendable {
    var message: String
    var confidence: AIConfidence
    var followUpSuggestions: [String]

    init(
        message: String,
        confidence: AIConfidence = .medium,
        followUpSuggestions: [String] = []
    ) {
        self.message = message
        self.confidence = confidence
        self.followUpSuggestions = followUpSuggestions
    }
}
