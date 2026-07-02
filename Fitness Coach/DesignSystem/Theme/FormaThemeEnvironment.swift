//
//  FormaThemeEnvironment.swift
//  Fitness Coach
//
//  Forma — SwiftUI environment for the resolved theme.
//

import SwiftUI

enum FormaThemeEnvironment {

    static let defaultResolvedTheme = ResolvedAppTheme.resolve(
        preferences: .default,
        systemColorScheme: .dark
    )
}

// MARK: - Environment keys

private struct FormaResolvedThemeKey: EnvironmentKey {
    static let defaultValue = FormaThemeEnvironment.defaultResolvedTheme
}

private struct FormaColorsKey: EnvironmentKey {
    static let defaultValue = FormaThemeEnvironment.defaultResolvedTheme.colors
}

private struct ThemePaletteKey: EnvironmentKey {
    static let defaultValue = FormaThemeEnvironment.defaultResolvedTheme.themePalette
}

extension EnvironmentValues {

    /// Fully resolved appearance + palette for the active screen tree.
    var formaResolvedTheme: ResolvedAppTheme {
        get { self[FormaResolvedThemeKey.self] }
        set {
            self[FormaResolvedThemeKey.self] = newValue
            self[FormaColorsKey.self] = newValue.colors
            self[ThemePaletteKey.self] = newValue.themePalette
        }
    }

    /// Semantic color palette for the active resolved theme.
    var formaColors: FormaColorPalette {
        get { self[FormaColorsKey.self] }
        set { self[FormaColorsKey.self] = newValue }
    }

    /// Canonical theme accent tokens for the active user palette.
    var themePalette: ThemePalette {
        get { self[ThemePaletteKey.self] }
        set { self[ThemePaletteKey.self] = newValue }
    }
}

// MARK: - Root injection

struct FormaThemeRootState: Equatable, Sendable {
    let resolved: ResolvedAppTheme
    let legacyPalette: FormaThemePalette
    let preferredColorScheme: ColorScheme?

    @MainActor
    static func make(
        store: ThemeStore,
        systemColorScheme: ColorScheme
    ) -> FormaThemeRootState {
        let resolved = store.resolvedTheme(systemColorScheme: systemColorScheme)
        let legacyPalette = store.legacyThemePalette(resolvingWith: systemColorScheme)
        return FormaThemeRootState(
            resolved: resolved,
            legacyPalette: legacyPalette,
            preferredColorScheme: store.preferredColorScheme
        )
    }
}

// MARK: - Preview helpers

extension View {

    /// Injects a fixed resolved theme (and legacy palette bridge) for previews.
    func formaResolvedTheme(_ theme: ResolvedAppTheme) -> some View {
        let legacyPalette = FormaPaletteCatalog.legacyThemePalette(
            for: theme.preferences.palette,
            colorScheme: theme.resolvedColorScheme
        )
        FormaThemeAccess.update(resolved: theme)
        return environment(\.formaResolvedTheme, theme)
            .environment(\.formaThemePalette, legacyPalette)
            .tint(theme.themePalette.primary)
    }

    /// Preview helper that mirrors root theme injection without a live `ThemeStore`.
    func formaThemePreview(
        appearance: AppAppearanceMode = .dark,
        palette: AppThemePalette = .oceanBlue,
        systemColorScheme: ColorScheme = .dark
    ) -> some View {
        let preferences = AppThemePreferences(appearance: appearance, palette: palette)
        let resolved = ThemeResolver.resolve(
            preferences: preferences,
            systemColorScheme: systemColorScheme
        )
        return preferredColorScheme(ThemeResolver.preferredColorScheme(for: appearance))
            .formaResolvedTheme(resolved)
    }
}
