//
//  HealthSignalKind.swift
//  Fitness Coach
//
//  Forma — Health Intelligence signal identifiers (HealthKit-agnostic).
//

import Foundation

enum HealthSignalKind: String, CaseIterable, Codable, Sendable, Hashable {
    // MARK: Required read permissions

    case stepCount
    case activeEnergyBurned
    case appleExerciseTime
    case workout
    case restingHeartRate
    case heartRateVariabilitySDNN
    case sleepAnalysis
    case bodyMass

    // MARK: Future optional permissions (declared, not requested by default)

    case walkingHeartRateAverage
    case vo2Max
    case distanceWalkingRunning
    case appleStandTime

    static let required: [HealthSignalKind] = [
        .stepCount,
        .activeEnergyBurned,
        .appleExerciseTime,
        .workout,
        .restingHeartRate,
        .heartRateVariabilitySDNN,
        .sleepAnalysis,
        .bodyMass
    ]

    static let futureOptional: [HealthSignalKind] = [
        .walkingHeartRateAverage,
        .vo2Max,
        .distanceWalkingRunning,
        .appleStandTime
    ]

    var requestPolicy: HealthSignalRequestPolicy {
        Self.required.contains(self) ? .required : .futureOptional
    }
}

enum HealthSignalRequestPolicy: Equatable, Sendable {
    case required
    case futureOptional
}
