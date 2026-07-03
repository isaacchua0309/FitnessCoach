//
//  RecoveryEngine.swift
//  Fitness Coach
//
//  Forma — Recovery readiness scoring from normalized health signals.
//

import Foundation

protocol RecoveryEngineing: Sendable {
    func recoverySummary(
        for date: Date,
        samples: [HealthNormalizedSample]
    ) async -> RecoverySummary
}

struct RecoveryEngine: RecoveryEngineing {

    func recoverySummary(
        for date: Date,
        samples: [HealthNormalizedSample]
    ) async -> RecoverySummary {
        // TODO: Combine sleep, resting HR, HRV, and recent training load into readiness score.
        _ = (date, samples)
        return .placeholder
    }
}
