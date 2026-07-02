//
//  AppThemePreferences.swift
//  Fitness Coach
//
//  Forma — Persisted theme user preferences.
//

import Foundation

struct AppThemePreferences: Equatable, Codable, Sendable {
    var appearance: AppAppearanceMode
    var palette: AppThemePalette

    static let `default` = AppThemePreferences(
        appearance: .dark,
        palette: .oceanBlue
    )

    enum PersistenceKey {
        static let appearance = "forma.theme.appearance"
        static let palette = "forma.theme.palette"
        /// Pre-canonical Settings storage key; read for migration only.
        static let legacyPalette = "forma.theme.colorPalette"
    }

    init(appearance: AppAppearanceMode, palette: AppThemePalette) {
        self.appearance = appearance
        self.palette = palette
    }

    /// Loads preferences from raw persisted strings with legacy fallbacks.
    init(appearanceRawValue: String?, paletteRawValue: String?) {
        appearance = AppAppearanceMode(storedRawValue: appearanceRawValue)
        palette = AppThemePalette(storedRawValue: paletteRawValue)
    }

    init(userDefaults: UserDefaults) {
        let paletteRaw = userDefaults.string(forKey: PersistenceKey.palette)
            ?? userDefaults.string(forKey: PersistenceKey.legacyPalette)

        self.init(
            appearanceRawValue: userDefaults.string(forKey: PersistenceKey.appearance),
            paletteRawValue: paletteRaw
        )
    }

    func write(to userDefaults: UserDefaults) {
        userDefaults.set(appearance.rawValue, forKey: PersistenceKey.appearance)
        userDefaults.set(palette.persistenceRawValue, forKey: PersistenceKey.palette)
    }
}
