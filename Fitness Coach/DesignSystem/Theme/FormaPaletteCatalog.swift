//
//  FormaPaletteCatalog.swift
//  Fitness Coach
//
//  Forma — Builds resolved `FormaColorPalette` from `ThemePaletteCatalog` + neutral base colors.
//

import SwiftUI

enum FormaPaletteCatalog {

    static let registeredThemePalettes: [AppThemePalette] = ThemePaletteCatalog.registeredPalettes
    static let registeredColorSchemes: [ColorScheme] = [.light, .dark]

    static func palette(
        for themePalette: AppThemePalette,
        colorScheme: ColorScheme
    ) -> FormaColorPalette {
        let theme = ThemePaletteCatalog.palette(for: themePalette, colorScheme: colorScheme)
        return formaColorPalette(from: theme, colorScheme: colorScheme)
    }

    static func themePalette(
        for themePalette: AppThemePalette,
        colorScheme: ColorScheme
    ) -> ThemePalette {
        ThemePaletteCatalog.palette(for: themePalette, colorScheme: colorScheme)
    }

    /// Default palette for the dark color scheme.
    static var defaultDark: FormaColorPalette {
        palette(for: .oceanBlue, colorScheme: .dark)
    }

    static var defaultThemePalette: ThemePalette {
        ThemePaletteCatalog.palette(for: .oceanBlue, colorScheme: .dark)
    }

    // MARK: - Legacy theme palette bridge

    static func legacyThemePalette(
        for themePalette: AppThemePalette,
        colorScheme: ColorScheme
    ) -> FormaThemePalette {
        let colors = palette(for: themePalette, colorScheme: colorScheme)
        return FormaThemePalette(colors: colors, colorScheme: colorScheme, theme: themePalette(for: themePalette, colorScheme: colorScheme))
    }

    // MARK: - Builder

    static func formaColorPalette(from theme: ThemePalette, colorScheme: ColorScheme) -> FormaColorPalette {
        let neutral = NeutralAppearanceColors.palette(for: colorScheme)
        let surface = theme.cardTint.opacity(colorScheme == .dark ? 0.07 : 0.05)
        let surfaceElevated = theme.cardTint.opacity(colorScheme == .dark ? 0.10 : 0.08)
        let surfaceSubtle = theme.cardTint.opacity(colorScheme == .dark ? 0.05 : 0.03)
        let border = theme.borderTint.opacity(colorScheme == .dark ? 0.12 : 0.10)
        let borderStrong = theme.borderTint.opacity(colorScheme == .dark ? 0.20 : 0.18)
        let borderSelected = theme.primary.opacity(0.72)
        let feedback = FeedbackPalette.palette(for: colorScheme)

        return FormaColorPalette(
            canvas: neutral.canvas,
            background: neutral.background,
            surface: surface,
            surfaceElevated: surfaceElevated,
            surfaceSubtle: surfaceSubtle,
            border: border,
            borderStrong: borderStrong,
            borderSelected: borderSelected,
            accent: theme.primary,
            accentPrimary: theme.primary,
            accentSecondary: theme.secondary,
            accentMuted: theme.softBackground,
            textPrimary: neutral.textPrimary,
            textSecondary: neutral.textSecondary,
            textTertiary: neutral.textTertiary,
            ctaBackground: theme.gradientStart,
            ctaText: theme.textOnAccent,
            progress: theme.primary,
            progressTrack: surfaceSubtle,
            selectedBackground: theme.softBackground,
            selectedBorder: borderSelected,
            chartPrimary: theme.primary,
            chartSecondary: theme.secondary,
            gradientStart: theme.gradientStart,
            gradientEnd: theme.gradientEnd,
            success: feedback.success,
            warning: feedback.warning,
            destructive: feedback.destructive,
            shadow: neutral.shadow
        )
    }
}

// MARK: - Shared feedback (not theme-tinted)

private enum FeedbackPalette {
    case dark
    case light

    static func palette(for colorScheme: ColorScheme) -> FeedbackPalette {
        colorScheme == .dark ? .dark : .light
    }

    var success: Color {
        switch self {
        case .dark: C.rgb(0.20, 0.78, 0.35)
        case .light: C.rgb(0.13, 0.62, 0.29)
        }
    }

    var warning: Color {
        switch self {
        case .dark: C.rgb(1.0, 0.58, 0.0)
        case .light: C.rgb(0.88, 0.45, 0.0)
        }
    }

    var destructive: Color {
        switch self {
        case .dark: C.rgb(1.0, 0.27, 0.23)
        case .light: C.rgb(0.88, 0.11, 0.16)
        }
    }
}

private enum C {
    static func rgb(_ red: Double, _ green: Double, _ blue: Double, opacity: Double = 1.0) -> Color {
        Color(red: red, green: green, blue: blue, opacity: opacity)
    }
}

// MARK: - Legacy mapping

extension FormaThemePalette {
    fileprivate init(colors: FormaColorPalette, colorScheme: ColorScheme, theme: ThemePalette) {
        let themeColors = ThemeColorProvider.colors(from: colors, colorScheme: colorScheme, themePalette: theme)
        self.init(
            canvas: themeColors.canvas,
            surface: themeColors.surface,
            surfaceElevated: themeColors.surfaceElevated,
            surfaceSubtle: themeColors.surfaceSubtle,
            border: themeColors.border,
            borderStrong: themeColors.borderStrong,
            borderSelected: themeColors.borderSelected,
            accent: themeColors.accent,
            accentMuted: themeColors.accentMuted,
            textPrimary: themeColors.textPrimary,
            textSecondary: themeColors.textSecondary,
            textTertiary: themeColors.textTertiary,
            textLegal: themeColors.textLegal,
            destructive: themeColors.destructive,
            warning: themeColors.warning,
            success: themeColors.success,
            googleButtonBackground: themeColors.googleButtonBackground,
            googleButtonText: themeColors.googleButtonForeground,
            googleButtonBorder: themeColors.googleButtonBorder,
            previewSwatchAccent: theme.primary,
            previewSwatchSurface: colors.surfaceElevated,
            previewSwatchCanvas: colors.canvas,
            iconSymbol: theme.iconSymbol
        )
    }
}
