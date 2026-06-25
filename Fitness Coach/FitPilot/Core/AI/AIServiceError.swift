//
//  AIServiceError.swift
//  Fitness Coach
//
//  FitPilot AI — Errors surfaced by the AI boundary.
//

import Foundation

enum AIServiceError: Error, Equatable {
    case invalidResponse(String)
    case validationFailed(String)
    case backendUnavailable
    case decodingFailed(String)
    case requestFailed(String)
    case featureDisabled

    /// Calm, user-facing message. Never exposes raw backend payloads or keys.
    var userMessage: String {
        switch self {
        case .featureDisabled:
            return "I couldn't reach the coach service. Try again in a moment."
        case .backendUnavailable, .requestFailed:
            return "I couldn't reach the coach service. Try again in a moment."
        case .invalidResponse, .decodingFailed, .validationFailed:
            return "I could not confidently understand that yet. "
                + "Please try rephrasing or log it with explicit calories and macros."
        }
    }
}
