//
//  ThemeTokens.swift
//  Fitness Coach
//
//  Forma — Canonical semantic theme roles for SwiftUI surfaces.
//

import SwiftUI

/// Semantic color roles resolved from the active user palette and appearance.
///
/// Prefer `@Environment(\.theme)` in views instead of palette-specific names
/// (`palette.primary`, `Color.blue`, etc.) or split `formaColors` / `themePalette` reads.
struct ThemeTokens: Equatable, Sendable {
    let appBackground: Color
    let cardBackground: Color
    let elevatedCardBackground: Color
    let primaryText: Color
    let secondaryText: Color
    let tertiaryText: Color
    let accent: Color
    let accentSoftBackground: Color
    let accentBorder: Color
    let accentLine: Color
    let buttonBackground: Color
    let buttonText: Color
    let progressTrack: Color
    let progressFill: Color
    let destructive: Color
    let warning: Color
    let success: Color
    let tabBarBackground: Color
    let tabBarSelectedBackground: Color
    let tabBarSelectedIcon: Color
    let tabBarUnselectedIcon: Color
    let inputBackground: Color
    let inputBorder: Color
}

enum ThemeTokensProvider {

    static let productDefault = tokens(
        from: FormaThemeEnvironment.defaultResolvedTheme
    )

    static func tokens(from resolved: ResolvedAppTheme) -> ThemeTokens {
        tokens(
            from: resolved.colors,
            themePalette: resolved.themePalette,
            colorScheme: resolved.resolvedColorScheme
        )
    }

    static func tokens(
        from colors: FormaColorPalette,
        themePalette: ThemePalette,
        colorScheme: ColorScheme
    ) -> ThemeTokens {
        let accentBorderOpacity: Double = colorScheme == .dark ? 0.45 : 0.40
        let accentLineOpacity: Double = 0.55

        return ThemeTokens(
            appBackground: colors.canvas,
            cardBackground: colors.surface,
            elevatedCardBackground: colors.surfaceElevated,
            primaryText: colors.textPrimary,
            secondaryText: colors.textSecondary,
            tertiaryText: colors.textTertiary,
            accent: themePalette.primary,
            accentSoftBackground: themePalette.softBackground,
            accentBorder: themePalette.borderTint.opacity(accentBorderOpacity),
            accentLine: themePalette.primary.opacity(accentLineOpacity),
            buttonBackground: themePalette.primaryButtonBackground,
            buttonText: themePalette.textOnAccent,
            progressTrack: colors.progressTrack,
            progressFill: colors.progress,
            destructive: colors.destructive,
            warning: colors.warning,
            success: colors.success,
            tabBarBackground: colors.canvas,
            tabBarSelectedBackground: colors.selectedBackground,
            tabBarSelectedIcon: themePalette.primary,
            tabBarUnselectedIcon: colors.textTertiary,
            inputBackground: colors.surfaceElevated,
            inputBorder: colors.border
        )
    }
}
