//
//  HealthSignal.swift
//  Fitness Coach
//
//  Forma — Presentation-facing health signal identifiers for integration status.
//

import Foundation

enum HealthSignal: String, Equatable, Sendable, Codable, CaseIterable {
    case steps
    case workouts
    case sleep
    case hrv
    case restingHeartRate
    case activeEnergy
}

extension HealthSignal {

    var displayLabel: String {
        switch self {
        case .steps: return "steps"
        case .workouts: return "workouts"
        case .sleep: return "sleep"
        case .hrv: return "HRV"
        case .restingHeartRate: return "resting heart rate"
        case .activeEnergy: return "active energy"
        }
    }
}
