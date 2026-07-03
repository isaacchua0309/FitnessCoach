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
    let remoteSyncEnabled: @Sendable () -> Bool

    init(
        permissionService: any HealthPermissionServing = HealthPermissionService(),
        remoteSyncService: (any HealthSummarySyncServing)? = nil,
        remoteSyncEnabled: @escaping @Sendable () -> Bool = {
            HealthIntelligenceFeatureFlags.healthSummaryRemoteSyncEnabled
        }
    ) {
        self.permissionService = permissionService
        self.remoteSyncService = remoteSyncService
        self.remoteSyncEnabled = remoteSyncEnabled
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
