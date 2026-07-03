//
//  HealthIntelligenceDebugEnvironment.swift
//  Fitness Coach
//
//  Forma — DEBUG-only environment hook for Health Intelligence verification.
//

#if DEBUG
import SwiftUI

private struct HealthIntelligenceDebugVerificationKey: EnvironmentKey {
    static let defaultValue: (@Sendable () async -> HealthIntelligenceSnapshotVerificationReport)? = nil
}

extension EnvironmentValues {
    var healthIntelligenceDebugVerification: (@Sendable () async -> HealthIntelligenceSnapshotVerificationReport)? {
        get { self[HealthIntelligenceDebugVerificationKey.self] }
        set { self[HealthIntelligenceDebugVerificationKey.self] = newValue }
    }
}
#endif
