//
//  SettingsDeleteDataActionHandler.swift
//  Fitness Coach
//
//  Forma — Delete data action gate for Settings row taps.
//

import Foundation

enum SettingsDeleteDataActionHandler {

    @discardableResult
    static func perform(
        scope: AccountDeletionScope,
        coordinator: AccountDeletionCoordinator?
    ) -> SettingsDeleteDataResult {
        guard SettingsDataDeletionCapability.isImplemented else {
            return .unavailable
        }

        guard coordinator != nil else {
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
        // TD-SETTINGS-002: Wire user data export when capability ships. See Docs/TechnicalDebt/TechnicalDebtRegister.md
        return false
    }
}
