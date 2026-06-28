//
//  ThemeColorProvider.swift
//  Fitness Coach
//
//  Forma — Builds semantic token facades from resolved palettes.
//

import SwiftUI

/// Maps canonical `FormaColorPalette` values into `FormaThemeColors` for static token access.
///
/// **Tradeoff:** `FormaTokens.Color` cannot read SwiftUI `@Environment` outside a `View` body.
/// `ThemeColorProvider` is published globally via `FormaThemeAccess`, which the root
/// `FormaRootThemeModifier` updates on every render. Prefer `@Environment(\.formaColors)` in
/// new SwiftUI code when environment is available.
enum ThemeColorProvider {

    static let productDefault = colors(
        from: FormaColorPaletteCatalog.defaultDark,
        colorScheme: .dark
    )

    static func colors(from resolved: ResolvedAppTheme) -> FormaThemeColors {
        colors(from: resolved.colors, colorScheme: resolved.resolvedColorScheme)
    }

    static func colors(
        from palette: FormaColorPalette,
        colorScheme: ColorScheme
    ) -> FormaThemeColors {
        let google = FormaBrandColorTokens.googleSignIn(
            colorScheme: colorScheme,
            borderBase: palette.border
        )

        return FormaThemeColors(
            canvas: palette.canvas,
            surface: palette.surface,
            surfaceElevated: palette.surfaceElevated,
            surfaceSubtle: palette.surfaceSubtle,
            border: palette.border,
            borderStrong: palette.borderStrong,
            borderSelected: palette.borderSelected,
            accent: palette.accent,
            accentMuted: palette.accentMuted,
            textPrimary: palette.textPrimary,
            textSecondary: palette.textSecondary,
            textTertiary: palette.textTertiary,
            textLegal: palette.textPrimary.opacity(0.62),
            ctaBackground: palette.ctaBackground,
            ctaText: palette.ctaText,
            progress: palette.progress,
            progressTrack: palette.progressTrack,
            chartPrimary: palette.chartPrimary,
            chartSecondary: palette.chartSecondary,
            shadow: palette.shadow,
            destructive: palette.destructive,
            warning: palette.warning,
            success: palette.success,
            googleButtonBackground: google.background,
            googleButtonForeground: google.foreground,
            googleButtonBorder: google.border,
            googleButtonShadow: google.shadow,
            googleButtonShadowLoading: google.shadowLoading
        )
    }
}
