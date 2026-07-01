//
//  HealthKitTrainingAuthorizing.swift
//  Fitness Coach
//
//  Forma — Protocol boundary for HealthKit training read authorization.
//

import Foundation

protocol HealthKitTrainingAuthorizing: Sendable {

    /// Whether HealthKit is available on this device (false on unsupported platforms).
    var isHealthDataAvailable: Bool { get }

    /// Legacy HealthKit sharing status (unreliable for read-only access). Prefer `resolveWorkoutReadAccess()`.
    func workoutReadAuthorizationStatus() -> HealthTrainingAuthorizationStatus

    /// Resolves effective read access using request status + a lightweight workout probe query.
    func resolveWorkoutReadAccess() async -> HealthTrainingAuthorizationStatus

    /// Requests read-only access for workout-related types. Never requests write access.
    func requestReadAuthorization() async -> HealthTrainingAuthorizationStatus
}
