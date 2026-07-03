//
//  HealthPermissionCategory.swift
//  Fitness Coach
//
//  Forma — User-facing Apple Health permission categories for privacy and settings UI.
//

import Foundation

/// Display-facing permission categories mapped to Health Intelligence signal kinds.
enum HealthPermissionCategory: String, CaseIterable, Equatable, Sendable, Hashable, Identifiable {
    case steps
    case workouts
    case activeEnergy
    case exerciseMinutes
    case sleep
    case restingHeartRate
    case hrv
    case weight

    var id: String { rawValue }

    /// Underlying Health Intelligence signal identifier.
    var signalKind: HealthSignalKind {
        switch self {
        case .steps:
            return .stepCount
        case .workouts:
            return .workout
        case .activeEnergy:
            return .activeEnergyBurned
        case .exerciseMinutes:
            return .appleExerciseTime
        case .sleep:
            return .sleepAnalysis
        case .restingHeartRate:
            return .restingHeartRate
        case .hrv:
            return .heartRateVariabilitySDNN
        case .weight:
            return .bodyMass
        }
    }

    /// Categories shown in privacy and permission education surfaces.
    static var displayCategories: [HealthPermissionCategory] {
        allCases
    }

    init?(signalKind: HealthSignalKind) {
        switch signalKind {
        case .stepCount:
            self = .steps
        case .workout:
            self = .workouts
        case .activeEnergyBurned:
            self = .activeEnergy
        case .appleExerciseTime:
            self = .exerciseMinutes
        case .sleepAnalysis:
            self = .sleep
        case .restingHeartRate:
            self = .restingHeartRate
        case .heartRateVariabilitySDNN:
            self = .hrv
        case .bodyMass:
            self = .weight
        case .walkingHeartRateAverage, .vo2Max, .distanceWalkingRunning, .appleStandTime:
            return nil
        }
    }
}
