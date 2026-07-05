//
//  ThemeStore.swift
//  Fitness Coach
//
//  Forma — Local theme preferences (UserDefaults-backed, not cloud-synced).
//
//  Single app-wide source of truth for theme palette and appearance. Injected once
//  at the root in `Fitness_CoachApp` via `environmentObject` + `formaRootTheme()` so
//  onboarding, auth, and main tabs all observe the same live palette.
//

import Combine
import SwiftUI

/// Single app-wide theme manager. Injected once at the root via `environmentObject`;
/// feature screens must observe this type (or `ThemeManager`) — never read UserDefaults
/// or construct independent instances for production UI.
typealias ThemeManager = ThemeStore

@MainActor
final class ThemeStore: ObservableObject {

    @Published private(set) var preferences: AppThemePreferences

    /// Bumps whenever palette or appearance changes so root injection can invalidate stale UI.
    @Published private(set) var themeRevision: UInt = 0

    private let userDefaults: UserDefaults
    private let analyticsLogger: any ThemeAnalyticsLogging

    init(
        userDefaults: UserDefaults = .standard,
        analyticsLogger: any ThemeAnalyticsLogging = NoOpThemeAnalyticsLogger()
    ) {
        self.userDefaults = userDefaults
        self.analyticsLogger = analyticsLogger
        var loaded = AppThemePreferences(userDefaults: userDefaults)
        loaded = Self.applyPersistedPaletteMigration(loaded, userDefaults: userDefaults)
        let sanitizedAppearance = AppThemeShippingPolicy.sanitizedAppearance(loaded.appearance)
        if sanitizedAppearance != loaded.appearance {
            loaded.appearance = sanitizedAppearance
            loaded.write(to: userDefaults)
        }
        preferences = loaded
        #if DEBUG
        ThemePersistenceDebugLogger.logLoaded(canonicalID: preferences.palette.persistenceRawValue)
        #endif
    }

    var appearance: AppAppearanceMode {
        preferences.appearance
    }

    var palette: AppThemePalette {
        preferences.palette
    }

    /// User-selected color theme (alias for `palette`).
    var selectedTheme: AppThemePalette {
        preferences.palette
    }

    /// Semantic tokens for the active theme resolved with the current system color scheme.
    func tokens(systemColorScheme: ColorScheme) -> ThemeTokens {
        ThemeTokensProvider.tokens(from: resolvedTheme(systemColorScheme: systemColorScheme))
    }

    var preferredColorScheme: ColorScheme? {
        ThemeResolver.preferredColorScheme(for: preferences.appearance)
    }

    func setAppearance(_ mode: AppAppearanceMode) {
        guard preferences.appearance != mode else { return }
        let previous = preferences.appearance
        var updated = preferences
        updated.appearance = mode
        commitPreferences(updated)
        analyticsLogger.log(
            .appearanceModeChanged,
            properties: .appearanceChange(previous: previous, new: mode)
        )
    }

    func setPalette(_ palette: AppThemePalette) {
        setTheme(palette)
    }

    /// Updates the selected color theme, persists to UserDefaults, and notifies all observers.
    func setTheme(_ theme: AppThemePalette) {
        guard selectedTheme != theme else { return }
        let previous = preferences.palette
        var updated = preferences
        updated.palette = theme
        commitPreferences(updated)
        analyticsLogger.log(
            .paletteChanged,
            properties: .paletteChange(previous: previous, new: theme)
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

    private func commitPreferences(_ updated: AppThemePreferences) {
        preferences = updated
        themeRevision &+= 1
        persist()
    }

    private func persist() {
        preferences.write(to: userDefaults)
        #if DEBUG
        ThemePersistenceDebugLogger.logPersisted(canonicalID: preferences.palette.persistenceRawValue)
        #endif
    }

    private static func applyPersistedPaletteMigration(
        _ preferences: AppThemePreferences,
        userDefaults: UserDefaults
    ) -> AppThemePreferences {
        let resolution = ThemePalettePersistence.resolveStoredPalette(
            primaryRawValue: userDefaults.string(forKey: AppThemePreferences.PersistenceKey.palette),
            legacyRawValue: userDefaults.string(forKey: AppThemePreferences.PersistenceKey.legacyPalette)
        )

        guard resolution.shouldRewriteCanonicalStore else { return preferences }

        var migrated = preferences
        migrated.palette = resolution.palette
        migrated.write(to: userDefaults)

        #if DEBUG
        if let reason = resolution.migrationReason, let storedRawValue = resolution.storedRawValue {
            ThemePersistenceDebugLogger.logMigration(
                from: storedRawValue,
                to: resolution.palette.persistenceRawValue,
                reason: reason
            )
        }
        #endif

        return migrated
    }

    /// Isolated defaults for SwiftUI previews — not used in production.
    static func previewUserDefaults() -> UserDefaults {
        let suiteName = "forma.theme.preview.\(UUID().uuidString)"
        return UserDefaults(suiteName: suiteName)!
    }
}
