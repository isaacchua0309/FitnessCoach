//
//  CoachTimelineEventType.swift
//  Fitness Coach
//
//  Forma — Canonical event kinds for the Coach timeline domain model.
//
//  Each case represents a discrete, persisted timeline fact. Event types are
//  stable contract identifiers used by compaction, queries, and AI context
//  builders. They do not imply UI presentation.
//

import Foundation

/// High-level category of a Coach timeline event.
enum CoachTimelineEventType: String, Codable, CaseIterable, Equatable, Sendable {

    // MARK: Conversation

    /// User-authored chat text (composer send or starter chip).
    case userMessage
    /// Assistant-authored chat text, including structured card accessibility text.
    case assistantMessage

    // MARK: Food lifecycle

    /// AI or local parser produced a food estimate awaiting review.
    case foodEstimateCreated
    /// Food entry committed to the daily log.
    case foodLogged
    /// User rejected a food estimate or pending confirmation.
    case foodRejected
    /// Existing food entry updated.
    case foodEdited
    /// Food entry removed from the daily log.
    case foodDeleted

    // MARK: Hydration & weight

    /// Water entry committed to the daily log.
    case waterLogged
    /// Weight entry committed (same-day upsert policy applies at persistence layer).
    case weightLogged

    // MARK: Apple Health activity

    /// Workout activity observed for the day (read-only; not a Coach mutation).
    case workoutDetected
    /// Step count refreshed for the day.
    case stepsUpdated

    // MARK: Meal photo analysis

    /// User attached a meal photo to the composer or sent an image message.
    case photoAttached
    /// Backend meal-image analysis started for a session.
    case photoAnalysisStarted
    /// Backend meal-image analysis returned a structured estimate.
    case photoAnalysisCompleted
    /// Backend or client pipeline failed during meal-image analysis.
    case photoAnalysisFailed

    // MARK: Clarification loop

    /// Assistant asked a clarifying question about a meal photo.
    case clarificationAsked
    /// User answered a meal-photo clarifying question.
    case clarificationAnswered

    // MARK: Pending confirmation

    /// Confirmation bar or sheet presented for a mutation or estimate.
    case pendingConfirmationCreated
    /// User confirmed a pending mutation from the bar or typed confirm.
    case pendingConfirmationConfirmed
    /// User rejected a pending mutation from the bar or typed cancel.
    case pendingConfirmationRejected

    // MARK: Undo & errors

    /// Coach undo removed or reversed a recent mutation.
    case undoPerformed
    /// AI gateway or client pipeline returned a recoverable backend error.
    case backendError
    /// Firebase auth/session failure blocked Coach AI.
    case authError

    // MARK: System & context

    /// App surfaces refreshed shared fitness state (no user-visible chat).
    case systemRefresh
    /// Health or Health Intelligence data was unavailable when context was built.
    case healthDataUnavailable
    /// Compact AI context packet assembled for an outbound request.
    case contextGenerated

    /// Forward-compatible fallback when persisted `eventTypeRaw` is unknown.
    case unknown
}
