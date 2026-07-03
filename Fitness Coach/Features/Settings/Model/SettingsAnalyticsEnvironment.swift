//
//  SettingsAnalyticsEnvironment.swift
//  Fitness Coach
//
//  Forma — SwiftUI environment injection for Settings analytics.
//

import SwiftUI

private struct SettingsAnalyticsCoordinatorKey: EnvironmentKey {
    @MainActor static let defaultValue = SettingsAnalyticsCoordinator()
}

extension EnvironmentValues {
    var settingsAnalyticsCoordinator: SettingsAnalyticsCoordinator {
        get { self[SettingsAnalyticsCoordinatorKey.self] }
        set { self[SettingsAnalyticsCoordinatorKey.self] = newValue }
    }
}
