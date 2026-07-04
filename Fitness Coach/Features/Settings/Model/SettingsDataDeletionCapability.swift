//
//  SettingsDataDeletionCapability.swift
//  Fitness Coach
//
//  Forma — Documents whether account/data deletion is implemented.
//

import Foundation

enum SettingsDataDeletionCapability {

    static var isImplemented: Bool { FormaAbTest.Settings.dataDeletionEnabled }

    static var isLocalDeviceOnlyEnabled: Bool {
        isImplemented && AccountDeletionPolicy.isScopeEnabled(.localDeviceOnly)
    }
}

enum SettingsDataExportCapability {

    static var isImplemented: Bool { FormaAbTest.Settings.dataExportEnabled }
}
