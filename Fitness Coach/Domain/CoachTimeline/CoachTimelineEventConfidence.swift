//
//  CoachTimelineEventConfidence.swift
//  Fitness Coach
//
//  Forma — Confidence metadata for Coach timeline events.
//

import Foundation

/// Confidence associated with an estimate, detection, or AI-derived fact.
///
/// Maps conceptually to `AIConfidence` and `ConfidenceLevel` without importing
/// infrastructure types into the domain layer.
enum CoachTimelineEventConfidence: String, Codable, CaseIterable, Equatable, Sendable {

    case high
    case medium
    case low
    /// Confidence could not be determined or does not apply.
    case unknown
}
