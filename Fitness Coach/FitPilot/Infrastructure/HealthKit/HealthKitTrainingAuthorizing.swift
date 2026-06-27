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

    /// Read authorization for workout samples — primary gate for Training Insights.
    func workoutReadAuthorizationStatus() -> HealthTrainingAuthorizationStatus

    /// Requests read-only access for workout-related types. Never requests write access.
    func requestReadAuthorization() async -> HealthTrainingAuthorizationStatus
}
