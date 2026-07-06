//
//  SettingsDependencies.swift
//  Fitness Coach
//
//  Settings and theme construction for AppContainer.
//  See Docs/Architecture/DependencyInjectionMap.md
//

import Foundation

extension AppContainer {

    struct SettingsDependenciesBundle {
        let themeStore: ThemeStore
    }

    static func buildSettingsDependencies(
        analytics: AnalyticsDependenciesBundle
    ) -> SettingsDependenciesBundle {
        SettingsDependenciesBundle(
            themeStore: ThemeStore(analyticsLogger: analytics.themeAnalyticsLogger)
        )
    }
}
