//
//  AppleHealthSettingsEnvironment.swift
//  Fitness Coach
//
//  Forma — Dependency injection for Settings → Apple Health.
//

import Foundation
import SwiftUI

struct AppleHealthSettingsEnvironment: Sendable {
    let permissionService: any HealthPermissionServing
    let remoteSyncService: (any HealthSummarySyncServing)?
    let remoteSyncCapabilityEnabled: @Sendable () -> Bool

    init(
        permissionService: any HealthPermissionServing = HealthPermissionService(),
        remoteSyncService: (any HealthSummarySyncServing)? = nil,
        remoteSyncCapabilityEnabled: @escaping @Sendable () -> Bool = {
            HealthIntelligenceFeatureFlags.healthSummaryRemoteSyncEnabled
        }
    ) {
        self.permissionService = permissionService
        self.remoteSyncService = remoteSyncService
        self.remoteSyncCapabilityEnabled = remoteSyncCapabilityEnabled
    }

    var isRemoteSyncCapabilityEnabled: Bool {
        remoteSyncCapabilityEnabled()
    }

    @MainActor
    func isRemoteSyncActive(consentStore: HealthSummarySyncConsentStore) -> Bool {
        HealthSummaryRemoteSyncGate.isActive(
            consent: consentStore.state,
            featureFlagEnabled: isRemoteSyncCapabilityEnabled
        )
    }

    static let production = AppleHealthSettingsEnvironment()
}

private struct AppleHealthSettingsEnvironmentKey: EnvironmentKey {
    static let defaultValue = AppleHealthSettingsEnvironment.production
}

extension EnvironmentValues {
    var appleHealthSettingsEnvironment: AppleHealthSettingsEnvironment {
        get { self[AppleHealthSettingsEnvironmentKey.self] }
        set { self[AppleHealthSettingsEnvironmentKey.self] = newValue }
    }
}
