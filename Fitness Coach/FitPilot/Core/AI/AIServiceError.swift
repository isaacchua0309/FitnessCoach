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
            return "AI parsing is currently disabled. Please log with explicit calories and macros for now."
        case .backendUnavailable, .requestFailed:
            return "AI parsing is not available right now, but local logging still works."
        case .invalidResponse, .decodingFailed, .validationFailed:
            return "I could not confidently understand that yet. "
                + "Please try rephrasing or log it with explicit calories and macros."
        }
    }
}
