//
//  SettingsPrivacyDataEnvironment.swift
//  Fitness Coach
//
//  Forma — Loads privacy-safe account/sync status for Settings.
//

import SwiftUI

struct SettingsPrivacyDataEnvironment: Sendable {
    var loadStatus: @Sendable () async -> SettingsPrivacyDataStatusSnapshot
}

private struct SettingsPrivacyDataEnvironmentKey: EnvironmentKey {
    static let defaultValue = SettingsPrivacyDataEnvironment {
        .empty
    }
}

extension EnvironmentValues {
    var settingsPrivacyDataEnvironment: SettingsPrivacyDataEnvironment {
        get { self[SettingsPrivacyDataEnvironmentKey.self] }
        set { self[SettingsPrivacyDataEnvironmentKey.self] = newValue }
    }
}
