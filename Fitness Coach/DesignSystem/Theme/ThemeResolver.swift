//
//  ThemeResolver.swift
//  Fitness Coach
//
//  Forma — Resolves appearance mode and palette into a render-ready theme.
//

import SwiftUI

enum ThemeResolver {

    static func resolve(
        preferences: AppThemePreferences,
        systemColorScheme: ColorScheme
    ) -> ResolvedAppTheme {
        let resolvedColorScheme = resolveColorScheme(
            appearance: preferences.appearance,
            systemColorScheme: systemColorScheme
        )
        let themePalette = ThemePaletteCatalog.palette(
            for: preferences.palette,
            colorScheme: resolvedColorScheme
        )
        let colors = FormaPaletteCatalog.formaColorPalette(
            from: themePalette,
            colorScheme: resolvedColorScheme
        )

        return ResolvedAppTheme(
            preferences: preferences,
            resolvedColorScheme: resolvedColorScheme,
            themePalette: themePalette,
            colors: colors
        )
    }

    static func resolveColorScheme(
        appearance: AppAppearanceMode,
        systemColorScheme: ColorScheme
    ) -> ColorScheme {
        switch appearance {
        case .system:
            return systemColorScheme
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    /// `nil` when appearance follows the system.
    static func preferredColorScheme(for appearance: AppAppearanceMode) -> ColorScheme? {
        switch appearance {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
