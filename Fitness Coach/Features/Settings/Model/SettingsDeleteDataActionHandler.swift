//
//  SettingsDeleteDataActionHandler.swift
//  Fitness Coach
//
//  Forma — Delete data action gate (no-op until deletion is implemented).
//

import Foundation

enum SettingsDeleteDataActionHandler {

    @discardableResult
    static func perform() -> SettingsDeleteDataResult {
        guard SettingsDataDeletionCapability.isImplemented else {
            return .notImplemented
        }
        // TODO: Wire local profile wipe and auth account deletion when capability ships.
        return .notImplemented
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
