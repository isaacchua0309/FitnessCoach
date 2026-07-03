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
    case payloadTooLarge
    case networkUnavailable
    case imageEncodingFailed
    case backendRejectedImage
    case modelUnavailable
    case invalidNutritionJSON(String)
    case parsingFailed(String)

    static let coachSessionFailureTitle = FormaProductCopy.Error.coachSessionTitle
    static let coachSessionFailureMessage = FormaProductCopy.Error.coachSessionMessage

    /// Calm, user-facing message. Never exposes raw backend payloads or keys.
    var userMessage: String {
        switch self {
        case .authenticationFailed:
            return Self.coachSessionFailureMessage
        case .requestTimedOut:
            return FormaProductCopy.Error.coachTimeout
        case .featureDisabled, .backendUnavailable, .modelUnavailable:
            return FormaProductCopy.Error.coachUnavailable
        case .networkUnavailable:
            return FormaProductCopy.Error.coachNetworkUnavailable
        case .payloadTooLarge:
            return FormaProductCopy.Error.coachPhotoTooLarge
        case .imageEncodingFailed:
            return FormaProductCopy.Error.coachPhotoEncodingFailed
        case .backendRejectedImage:
            return FormaProductCopy.Error.coachPhotoRejected
        case .requestFailed:
            return FormaProductCopy.Error.coachUnavailable
        case .invalidNutritionJSON, .parsingFailed:
            return FormaProductCopy.Error.coachPhotoAnalysisUnreadable
        case .invalidResponse, .decodingFailed, .validationFailed:
            return FormaProductCopy.Error.coachNotUnderstood
        }
    }

    /// Transient failures eligible for a single classifier retry.
    var isTransientClassifierFailure: Bool {
        switch self {
        case .backendUnavailable, .requestFailed, .decodingFailed, .requestTimedOut,
             .networkUnavailable, .modelUnavailable:
            return true
        case .authenticationFailed, .validationFailed, .invalidResponse, .featureDisabled,
             .payloadTooLarge, .imageEncodingFailed, .backendRejectedImage,
             .invalidNutritionJSON, .parsingFailed:
            return false
        }
    }
}
