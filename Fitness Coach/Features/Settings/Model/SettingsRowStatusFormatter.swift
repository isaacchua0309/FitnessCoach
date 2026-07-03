//
//  SettingsRowStatusFormatter.swift
//  Fitness Coach
//
//  Forma — Concise status labels for the Settings hub.
//

import Foundation

enum SettingsRowStatusFormatter {

    static func unitSystem(_ unitSystem: UnitSystem) -> String {
        switch unitSystem {
        case .metric:
            return FormaProductCopy.Settings.Status.metric
        case .imperial:
            return FormaProductCopy.Settings.Status.imperial
        }
    }

    static func themePalette(_ palette: AppThemePalette) -> String {
        palette.displayName
    }

    static func appleHealth(_ state: TrainingIntegrationState) -> String {
        state.isConnected
            ? FormaProductCopy.Settings.Status.connected
            : FormaProductCopy.Settings.Status.notConnected
    }
}
