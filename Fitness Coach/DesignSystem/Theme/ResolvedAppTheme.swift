//
//  ResolvedAppTheme.swift
//  Fitness Coach
//
//  Forma — Fully resolved theme for rendering.
//

import SwiftUI

struct ResolvedAppTheme: Equatable, Sendable {
    let preferences: AppThemePreferences
    let resolvedColorScheme: ColorScheme
    let colors: FormaColorPalette

    static func resolve(
        preferences: AppThemePreferences = .default,
        systemColorScheme: ColorScheme
    ) -> ResolvedAppTheme {
        ThemeResolver.resolve(
            preferences: preferences,
            systemColorScheme: systemColorScheme
        )
    }
}
