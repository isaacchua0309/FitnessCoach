//
//  SettingsDependencies.swift
//  Fitness Coach
//
//  Typed settings shell bundle for AppContainer wiring.
//

import Foundation

/// Resolved settings dependencies for `AppContainer`.
struct SettingsDependencies {
    let themeStore: ThemeStore

    static func build(analytics: AnalyticsDependencies) -> SettingsDependencies {
        SettingsDependencies(
            themeStore: ThemeStore(analyticsLogger: analytics.themeAnalyticsLogger)
        )
    }
}
