//
//  ThemeStore.swift
//  Fitness Coach
//
//  Forma — Local theme preferences (UserDefaults-backed, not cloud-synced).
//

import Combine
import SwiftUI

@MainActor
final class ThemeStore: ObservableObject {

    @Published private(set) var preferences: AppThemePreferences {
        didSet { persist() }
    }

    private let userDefaults: UserDefaults
    private let analyticsLogger: any ThemeAnalyticsLogging

    init(
        userDefaults: UserDefaults = .standard,
        analyticsLogger: any ThemeAnalyticsLogging = NoOpThemeAnalyticsLogger()
    ) {
        self.userDefaults = userDefaults
        self.analyticsLogger = analyticsLogger
        var loaded = AppThemePreferences(userDefaults: userDefaults)
        loaded = Self.migratePersistedPaletteIfNeeded(loaded, userDefaults: userDefaults)
        let sanitizedAppearance = AppThemeShippingPolicy.sanitizedAppearance(loaded.appearance)
        if sanitizedAppearance != loaded.appearance {
            loaded.appearance = sanitizedAppearance
            loaded.write(to: userDefaults)
        }
        preferences = loaded
    }

    var appearance: AppAppearanceMode {
        preferences.appearance
    }

    var palette: AppThemePalette {
        preferences.palette
    }

    var preferredColorScheme: ColorScheme? {
        ThemeResolver.preferredColorScheme(for: preferences.appearance)
    }

    func setAppearance(_ mode: AppAppearanceMode) {
        guard preferences.appearance != mode else { return }
        let previous = preferences.appearance
        preferences.appearance = mode
        analyticsLogger.log(
            .appearanceModeChanged,
            properties: .appearanceChange(previous: previous, new: mode)
        )
    }

    func setPalette(_ palette: AppThemePalette) {
        guard preferences.palette != palette else { return }
        let previous = preferences.palette
        preferences.palette = palette
        analyticsLogger.log(
            .paletteChanged,
            properties: .paletteChange(previous: previous, new: palette)
        )
    }

    func recordSettingsViewed(source: ThemeAnalyticsSource = .settings) {
        analyticsLogger.log(.settingsViewed, properties: .settingsViewed(source: source))
    }

    func resolvedTheme(systemColorScheme: ColorScheme) -> ResolvedAppTheme {
        ThemeResolver.resolve(
            preferences: preferences,
            systemColorScheme: systemColorScheme
        )
    }

    /// Legacy `FormaThemePalette` for existing token bridges and Settings previews.
    func legacyThemePalette(resolvingWith systemColorScheme: ColorScheme) -> FormaThemePalette {
        let resolved = resolvedTheme(systemColorScheme: systemColorScheme)
        return FormaPaletteCatalog.legacyThemePalette(
            for: preferences.palette,
            colorScheme: resolved.resolvedColorScheme
        )
    }

    func previewLegacyThemePalette(
        for palette: AppThemePalette,
        resolvingWith systemColorScheme: ColorScheme
    ) -> FormaThemePalette {
        let resolvedScheme = ThemeResolver.resolveColorScheme(
            appearance: preferences.appearance,
            systemColorScheme: systemColorScheme
        )
        return FormaPaletteCatalog.legacyThemePalette(
            for: palette,
            colorScheme: resolvedScheme
        )
    }

    // MARK: - Persistence

    private func persist() {
        preferences.write(to: userDefaults)
    }

    private static func migratePersistedPaletteIfNeeded(
        _ preferences: AppThemePreferences,
        userDefaults: UserDefaults
    ) -> AppThemePreferences {
        let storedRaw = userDefaults.string(forKey: AppThemePreferences.PersistenceKey.palette)
            ?? userDefaults.string(forKey: AppThemePreferences.PersistenceKey.legacyPalette)
        guard let storedRaw else { return preferences }
        guard AppThemePalette.shouldMigratePersistedRawValue(storedRaw) else { return preferences }

        var migrated = preferences
        migrated.palette = AppThemePalette(storedRawValue: storedRaw)
        migrated.write(to: userDefaults)
        return migrated
    }
}
