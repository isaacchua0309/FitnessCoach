//
//  FormaThemeAccess.swift
//  Fitness Coach
//
//  Forma — Bridges dynamic palettes into static FormaTokens call sites.
//

import SwiftUI

/// Controlled global bridge for non-View code paths and legacy `FormaTokens.Color` call sites.
///
/// **Tradeoff:** SwiftUI environment is only available inside `View` bodies. Static token access
/// (`FormaTokens.Color.accent`) reads `currentColors`, which `FormaRootThemeModifier` updates
/// synchronously at the app root. Until the first root update, values fall back to
/// `ThemeColorProvider.productDefault`. Prefer `@Environment(\.themePalette)` in new views.
@MainActor
enum FormaThemeAccess {
    private(set) static var currentResolvedTheme: ResolvedAppTheme = ResolvedAppTheme.resolve(
        preferences: .default,
        systemColorScheme: .dark
    )
    private(set) static var currentThemePalette: ThemePalette = FormaPaletteCatalog.defaultThemePalette
    private(set) static var currentColors: FormaThemeColors = ThemeColorProvider.productDefault
    private(set) static var currentPalette: FormaThemePalette = .defaultOceanBlue

    static func update(resolved: ResolvedAppTheme) {
        currentResolvedTheme = resolved
        currentThemePalette = resolved.themePalette
        currentColors = ThemeColorProvider.colors(from: resolved)
        currentPalette = FormaPaletteCatalog.legacyThemePalette(
            for: resolved.preferences.palette,
            colorScheme: resolved.resolvedColorScheme
        )
    }

    static func update(colors: FormaThemeColors, legacyPalette: FormaThemePalette) {
        currentColors = colors
        currentThemePalette = colors.themePalette
        currentPalette = legacyPalette
    }

    /// Legacy entry point — prefer `update(resolved:)`.
    static func update(palette: FormaThemePalette) {
        currentPalette = palette
    }

    static func resetToProductDefault() {
        let resolved = ResolvedAppTheme.resolve(preferences: .default, systemColorScheme: .dark)
        update(resolved: resolved)
    }
}
