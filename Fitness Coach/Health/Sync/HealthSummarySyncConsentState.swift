//
//  HealthSummarySyncConsentState.swift
//  Fitness Coach
//
//  Forma — User consent for remote Health Summary Sync.
//

import Foundation

enum HealthSummarySyncConsentDecision: String, Equatable, Sendable, Codable {
    case notDetermined
    case optedIn
    case optedOut
}

struct HealthSummarySyncConsentState: Equatable, Sendable, Codable {
    let decision: HealthSummarySyncConsentDecision
    let updatedAt: Date

    var isRemoteSyncAllowed: Bool {
        decision == .optedIn
    }

    var hasExplicitDecision: Bool {
        decision != .notDetermined
    }

    static let `default` = HealthSummarySyncConsentState(
        decision: .notDetermined,
        updatedAt: .distantPast
    )

    func updating(
        decision: HealthSummarySyncConsentDecision,
        updatedAt: Date = Date()
    ) -> HealthSummarySyncConsentState {
        HealthSummarySyncConsentState(
            decision: decision,
            updatedAt: updatedAt
        )
    }
}

enum HealthSummaryRemoteSyncGate {

    static func isCapabilityEnabled(
        featureFlagEnabled: Bool = HealthIntelligenceFeatureFlags.healthSummaryRemoteSyncEnabled
    ) -> Bool {
        featureFlagEnabled
    }

    static func isActive(
        consent: HealthSummarySyncConsentState,
        featureFlagEnabled: Bool = HealthIntelligenceFeatureFlags.healthSummaryRemoteSyncEnabled
    ) -> Bool {
        isCapabilityEnabled(featureFlagEnabled: featureFlagEnabled) && consent.isRemoteSyncAllowed
    }
}
