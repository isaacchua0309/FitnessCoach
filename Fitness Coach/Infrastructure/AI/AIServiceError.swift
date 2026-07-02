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
    case requestTimedOut
    case featureDisabled
    case authenticationFailed

    static let coachSessionFailureTitle = FormaProductCopy.Error.coachSessionTitle
    static let coachSessionFailureMessage = FormaProductCopy.Error.coachSessionMessage

    /// Calm, user-facing message. Never exposes raw backend payloads or keys.
    var userMessage: String {
        switch self {
        case .authenticationFailed:
            return Self.coachSessionFailureMessage
        case .requestTimedOut:
            return FormaProductCopy.Error.coachTimeout
        case .featureDisabled:
            return FormaProductCopy.Error.coachUnavailable
        case .backendUnavailable, .requestFailed:
            return FormaProductCopy.Error.coachUnavailable
        case .invalidResponse, .decodingFailed, .validationFailed:
            return FormaProductCopy.Error.coachNotUnderstood
        }
    }

    /// Transient failures eligible for a single classifier retry.
    var isTransientClassifierFailure: Bool {
        switch self {
        case .backendUnavailable, .requestFailed, .decodingFailed, .requestTimedOut:
            return true
        case .authenticationFailed, .validationFailed, .invalidResponse, .featureDisabled:
            return false
        }
    }
}
