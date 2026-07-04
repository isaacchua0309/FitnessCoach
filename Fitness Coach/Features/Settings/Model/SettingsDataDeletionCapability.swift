//
//  SettingsDataDeletionCapability.swift
//  Fitness Coach
//
//  Forma — Documents whether account/data deletion is implemented.
//

import Foundation

enum SettingsDataDeletionCapability {

    /// TODO: Set to `true` when local profile wipe and auth account deletion are wired.
    static var isImplemented: Bool { FormaAbTest.Settings.dataDeletionEnabled }
}

enum SettingsDataExportCapability {

    static var isImplemented: Bool { FormaAbTest.Settings.dataExportEnabled }
}
