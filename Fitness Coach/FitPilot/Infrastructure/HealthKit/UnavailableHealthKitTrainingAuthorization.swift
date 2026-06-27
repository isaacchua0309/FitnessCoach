//
//  UnavailableHealthKitTrainingAuthorization.swift
//  Fitness Coach
//
//  Forma — Fallback when HealthKit is not supported on the current platform.
//

import Foundation

struct UnavailableHealthKitTrainingAuthorization: HealthKitTrainingAuthorizing, Sendable {

    var isHealthDataAvailable: Bool { false }

    func workoutReadAuthorizationStatus() -> HealthTrainingAuthorizationStatus {
        .unavailable
    }

    func resolveWorkoutReadAccess() async -> HealthTrainingAuthorizationStatus {
        .unavailable
    }

    func requestReadAuthorization() async -> HealthTrainingAuthorizationStatus {
        .unavailable
    }
}
