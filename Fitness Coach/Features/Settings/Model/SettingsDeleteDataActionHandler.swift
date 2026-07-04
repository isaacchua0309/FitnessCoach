//
//  SettingsDeleteDataActionHandler.swift
//  Fitness Coach
//
//  Forma — Delete data action gate for Settings row taps.
//

import Foundation

enum SettingsDeleteDataActionHandler {

    @discardableResult
    static func perform(scope: AccountDeletionScope) -> SettingsDeleteDataResult {
        guard SettingsDataDeletionCapability.isImplemented else {
            return .unavailable
        }

        switch scope {
        case .fullAccount:
            return .opensDeletionFlow
        case .localDeviceOnly:
            guard SettingsDataDeletionCapability.isLocalDeviceOnlyEnabled else {
                return .unavailable
            }
            return .opensDeletionFlow
        case .remoteAccountDataOnly:
            return .unavailable
        }
    }
}

enum SettingsExportDataActionHandler {

    @discardableResult
    static func perform() -> Bool {
        guard SettingsDataExportCapability.isImplemented else {
            return false
        }
        // TODO: Wire user data export when capability ships.
        return false
    }
}
