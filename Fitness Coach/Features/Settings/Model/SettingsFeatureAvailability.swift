//
//  SettingsFeatureAvailability.swift
//  Fitness Coach
//
//  Forma — Feature flags for Settings row visibility.
//

import Foundation

struct SettingsFeatureAvailability: Equatable, Sendable {
    let isDataExportEnabled: Bool
    let isDeleteAccountEnabled: Bool
    let isDeleteLocalDeviceDataEnabled: Bool

    /// Production flags — export/delete rows appear only when capability is implemented.
    static let production = SettingsFeatureAvailability(
        isDataExportEnabled: SettingsDataExportCapability.isImplemented,
        isDeleteAccountEnabled: SettingsDataDeletionCapability.isImplemented,
        isDeleteLocalDeviceDataEnabled: SettingsDataDeletionCapability.isLocalDeviceOnlyEnabled
    )
}
