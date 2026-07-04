//
//  CoachTimelineEventStatus.swift
//  Fitness Coach
//
//  Forma — Lifecycle status for Coach timeline events.
//

import Foundation

/// Lifecycle state of a timeline event relative to user confirmation and corrections.
enum CoachTimelineEventStatus: String, Codable, CaseIterable, Equatable, Sendable {

    /// Awaiting user confirmation (estimate, pending bar, or in-flight analysis).
    case pending
    /// User confirmed or mutation committed successfully.
    case confirmed
    /// User rejected an estimate or pending mutation.
    case rejected
    /// Operation failed (network, validation, auth).
    case failed
    /// Replaced by a newer event (`supersedesEventId` points to the prior event).
    case superseded
}
