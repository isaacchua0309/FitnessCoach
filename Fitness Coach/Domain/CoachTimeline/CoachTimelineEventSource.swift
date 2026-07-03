//
//  CoachTimelineEventSource.swift
//  Fitness Coach
//
//  Forma — Origin channel for Coach timeline events.
//

import Foundation

/// Broad origin channel for a timeline event.
///
/// Use `CoachTimelineEventSourceAttribution` for pipeline-specific detail
/// (classifier vs meal image vs HealthKit sync).
enum CoachTimelineEventSource: String, Codable, CaseIterable, Equatable, Sendable {

    /// User interaction inside the Coach feature (composer, chips, confirmation).
    case coachUI
    /// Deterministic on-device parsing or routing without a network round-trip.
    case localPipeline
    /// FitPilot AI gateway / LLM-backed endpoints.
    case aiBackend
    /// Apple Health or Health Intelligence read path (never mutates logs).
    case healthSync
    /// App infrastructure (refresh center, bootstrap, timeline store).
    case system
}

/// Fine-grained attribution for how an event entered the timeline.
///
/// Attribution is stable for analytics, compaction, and AI context auditing.
enum CoachTimelineEventSourceAttribution: String, Codable, CaseIterable, Equatable, Sendable {

    /// `LocalCommandParser` or `CoachRouteDecider` local guard.
    case localParser
    /// Cheap LLM intent classifier (`classify-coach-intent`).
    case classifier
    /// Text food estimate endpoint (`estimate-food`).
    case estimateFood
    /// Meal image analysis endpoint (`analyze-meal-image`).
    case mealImage
    /// User explicitly confirmed or rejected a pending mutation.
    case userConfirmation
    /// Apple HealthKit workout or step reads.
    case healthKit
    /// Health Intelligence snapshot composition.
    case healthIntelligence
    /// System-generated events (refresh, compaction, context assembly).
    case system
}
