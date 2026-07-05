//
//  SettingsDataDeletionCapability.swift
//  Fitness Coach
//
//  Forma — Documents whether account/data deletion is implemented.
//
//  **Owner:** Settings / privacy platform.
//  **Registry:** `Docs/Architecture/FeatureFlagRegistry.md` § Settings.
//
//  Deletion: `FormaAbTest.Settings.dataDeletionEnabled` (production intent: `true`).
//  Export: `AccountDataExportPolicy.isEnabled` — not a FormaAbTest flag (see registry).
//

import Foundation

enum SettingsDataDeletionCapability {

    static var isImplemented: Bool { FormaAbTest.Settings.dataDeletionEnabled }

    static var isLocalDeviceOnlyEnabled: Bool {
        isImplemented && AccountDeletionPolicy.isScopeEnabled(.localDeviceOnly)
    }
}

enum SettingsDataExportCapability {

    static var isImplemented: Bool { AccountDataExportPolicy.isEnabled }
}
