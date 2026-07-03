//
//  SettingsFeatureAvailability.swift
//  Fitness Coach
//
//  Forma — Feature flags for Settings row visibility.
//

import Foundation

struct SettingsFeatureAvailability: Equatable, Sendable {
    let isDataExportEnabled: Bool
    let isDeleteDataEnabled: Bool

    static let production = SettingsFeatureAvailability(
        isDataExportEnabled: false,
        isDeleteDataEnabled: false
    )
}
