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
            let result = SettingsDeleteDataResult.unavailable
            AccountDeletionDebugEventLogger.settingsDeleteDataAction(scope: scope, result: result)
            return result
        }

        switch scope {
        case .fullAccount:
            let result = SettingsDeleteDataResult.opensDeletionFlow
            AccountDeletionDebugEventLogger.settingsDeleteDataAction(scope: scope, result: result)
            return result
        case .localDeviceOnly:
            guard SettingsDataDeletionCapability.isLocalDeviceOnlyEnabled else {
                let result = SettingsDeleteDataResult.unavailable
                AccountDeletionDebugEventLogger.settingsDeleteDataAction(scope: scope, result: result)
                return result
            }
            let result = SettingsDeleteDataResult.opensDeletionFlow
            AccountDeletionDebugEventLogger.settingsDeleteDataAction(scope: scope, result: result)
            return result
        case .remoteAccountDataOnly:
            let result = SettingsDeleteDataResult.unavailable
            AccountDeletionDebugEventLogger.settingsDeleteDataAction(scope: scope, result: result)
            return result
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
