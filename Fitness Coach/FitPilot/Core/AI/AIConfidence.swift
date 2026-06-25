//
//  AIConfidence.swift
//  Fitness Coach
//
//  FitPilot AI — Confidence level reported by the AI boundary.
//

import Foundation

enum AIConfidence: String, Codable, Equatable, Sendable {
    case high
    case medium
    case low

    /// Maps the AI confidence onto the Core domain confidence level used by
    /// food entries.
    var asConfidenceLevel: ConfidenceLevel {
        switch self {
        case .high:
            return .high
        case .medium:
            return .medium
        case .low:
            return .low
        }
    }
}
