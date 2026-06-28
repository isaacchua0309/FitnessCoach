//
//  FormaPaletteCatalog.swift
//  Fitness Coach
//
//  Forma — Registered palette catalog (sole source of raw color values).
//

import SwiftUI

enum FormaPaletteCatalog {

    static let registeredThemePalettes: [AppThemePalette] = AppThemePalette.allCases
    static let registeredColorSchemes: [ColorScheme] = [.light, .dark]

    static func palette(
        for themePalette: AppThemePalette,
        colorScheme: ColorScheme
    ) -> FormaColorPalette {
        switch (themePalette, colorScheme) {
        case (.default, .dark):
            return defaultFormaDark
        case (.default, .light):
            return defaultFormaLight
        case (.pink, .dark):
            return pinkDark
        case (.pink, .light):
            return pinkLight
        case (.coolBlue, .dark):
            return coolBlueDark
        case (.coolBlue, .light):
            return coolBlueLight
        case (_, .dark):
            return defaultFormaDark
        case (_, .light):
            return defaultFormaLight
        }
    }

    /// Default Forma palette for the dark color scheme — matches legacy production tokens.
    static var defaultDark: FormaColorPalette { defaultFormaDark }

    // MARK: - Default Forma

    private static let defaultFormaDark = makeDarkPalette(
        canvas: C.rgb(0.03, 0.05, 0.08),
        surfaceTint: C.rgb(1.0, 1.0, 1.0),
        accent: C.rgb(0.0, 0.48, 1.0),
        ctaBackground: C.rgb(0.0, 0.42, 0.92),
        ctaText: C.rgb(1.0, 1.0, 1.0),
        feedback: .dark
    )

    private static let defaultFormaLight = makeLightPalette(
        canvas: C.rgb(0.97, 0.97, 0.98),
        ink: C.rgb(0.08, 0.09, 0.11),
        accent: C.rgb(0.0, 0.40, 0.90),
        ctaBackground: C.rgb(0.0, 0.34, 0.78),
        ctaText: C.rgb(1.0, 1.0, 1.0),
        feedback: .light
    )

    // MARK: - Pink

    private static let pinkDark = makeDarkPalette(
        canvas: C.rgb(0.10, 0.05, 0.07),
        surfaceTint: C.rgb(1.0, 0.94, 0.96),
        accent: C.rgb(1.0, 0.42, 0.58),
        ctaBackground: C.rgb(0.76, 0.10, 0.36),
        ctaText: C.rgb(1.0, 1.0, 1.0),
        feedback: .dark
    )

    private static let pinkLight = makeLightPalette(
        canvas: C.rgb(0.99, 0.96, 0.95),
        ink: C.rgb(0.16, 0.07, 0.10),
        accent: C.rgb(0.82, 0.18, 0.48),
        ctaBackground: C.rgb(0.72, 0.10, 0.38),
        ctaText: C.rgb(1.0, 1.0, 1.0),
        feedback: .light
    )

    // MARK: - Cool Blue

    private static let coolBlueDark = makeDarkPalette(
        canvas: C.rgb(0.03, 0.05, 0.12),
        surfaceTint: C.rgb(0.90, 0.95, 1.0),
        accent: C.rgb(0.40, 0.70, 0.98),
        ctaBackground: C.rgb(0.12, 0.38, 0.74),
        ctaText: C.rgb(1.0, 1.0, 1.0),
        feedback: .dark
    )

    private static let coolBlueLight = makeLightPalette(
        canvas: C.rgb(0.95, 0.97, 1.0),
        ink: C.rgb(0.06, 0.10, 0.18),
        accent: C.rgb(0.15, 0.45, 0.82),
        ctaBackground: C.rgb(0.10, 0.34, 0.68),
        ctaText: C.rgb(1.0, 1.0, 1.0),
        feedback: .light
    )

    // MARK: - Builders

    private static func makeDarkPalette(
        canvas: Color,
        surfaceTint: Color,
        accent: Color,
        ctaBackground: Color? = nil,
        ctaText: Color,
        feedback: FeedbackPalette
    ) -> FormaColorPalette {
        let resolvedCTABackground = ctaBackground ?? accent
        let surface = surfaceTint.opacity(0.07)
        let surfaceElevated = surfaceTint.opacity(0.10)
        let surfaceSubtle = surfaceTint.opacity(0.05)
        let border = surfaceTint.opacity(0.12)
        let borderStrong = surfaceTint.opacity(0.20)
        let textPrimary = C.rgb(1.0, 1.0, 1.0)
        let textSecondary = textPrimary.opacity(0.68)
        let textTertiary = textPrimary.opacity(0.48)
        let accentMuted = accent.opacity(0.16)
        let borderSelected = accent.opacity(0.72)
        let accentSecondary = accent.opacity(0.72)
        let chartSecondary = accent.opacity(0.55)

        return FormaColorPalette(
            canvas: canvas,
            background: canvas,
            surface: surface,
            surfaceElevated: surfaceElevated,
            surfaceSubtle: surfaceSubtle,
            border: border,
            borderStrong: borderStrong,
            borderSelected: borderSelected,
            accent: accent,
            accentPrimary: accent,
            accentSecondary: accentSecondary,
            accentMuted: accentMuted,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            textTertiary: textTertiary,
            ctaBackground: resolvedCTABackground,
            ctaText: ctaText,
            progress: accent,
            progressTrack: surfaceSubtle,
            selectedBackground: accentMuted,
            selectedBorder: borderSelected,
            chartPrimary: accent,
            chartSecondary: chartSecondary,
            success: feedback.success,
            warning: feedback.warning,
            destructive: feedback.destructive,
            shadow: C.rgb(0.0, 0.0, 0.0, opacity: 0.35)
        )
    }

    private static func makeLightPalette(
        canvas: Color,
        ink: Color,
        accent: Color,
        ctaBackground: Color? = nil,
        ctaText: Color,
        feedback: FeedbackPalette
    ) -> FormaColorPalette {
        let resolvedCTABackground = ctaBackground ?? accent
        let surface = ink.opacity(0.05)
        let surfaceElevated = ink.opacity(0.08)
        let surfaceSubtle = ink.opacity(0.03)
        let border = ink.opacity(0.10)
        let borderStrong = ink.opacity(0.18)
        let textPrimary = ink
        let textSecondary = ink.opacity(0.68)
        let textTertiary = ink.opacity(0.48)
        let accentMuted = accent.opacity(0.14)
        let borderSelected = accent.opacity(0.72)
        let accentSecondary = accent.opacity(0.76)
        let chartSecondary = accent.opacity(0.58)

        return FormaColorPalette(
            canvas: canvas,
            background: canvas,
            surface: surface,
            surfaceElevated: surfaceElevated,
            surfaceSubtle: surfaceSubtle,
            border: border,
            borderStrong: borderStrong,
            borderSelected: borderSelected,
            accent: accent,
            accentPrimary: accent,
            accentSecondary: accentSecondary,
            accentMuted: accentMuted,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            textTertiary: textTertiary,
            ctaBackground: resolvedCTABackground,
            ctaText: ctaText,
            progress: accent,
            progressTrack: surfaceSubtle,
            selectedBackground: accentMuted,
            selectedBorder: borderSelected,
            chartPrimary: accent,
            chartSecondary: chartSecondary,
            success: feedback.success,
            warning: feedback.warning,
            destructive: feedback.destructive,
            shadow: C.rgb(0.0, 0.0, 0.0, opacity: 0.12)
        )
    }

    // MARK: - Legacy theme palette bridge

    static func legacyThemePalette(
        for colorTheme: FormaColorPaletteID,
        colorScheme: ColorScheme
    ) -> FormaThemePalette {
        let colors = palette(for: appThemePalette(from: colorTheme), colorScheme: colorScheme)
        return FormaThemePalette(colors: colors, colorScheme: colorScheme)
    }

    private static func appThemePalette(from legacyID: FormaColorPaletteID) -> AppThemePalette {
        switch legacyID {
        case .defaultForma: .default
        case .pink: .pink
        case .coolBlue: .coolBlue
        }
    }
}

// MARK: - Primitives (catalog-internal only)

private enum C {
    static func rgb(_ red: Double, _ green: Double, _ blue: Double, opacity: Double = 1.0) -> Color {
        Color(red: red, green: green, blue: blue, opacity: opacity)
    }
}

private enum FeedbackPalette {
    case dark
    case light

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

// MARK: - Legacy mapping

extension FormaThemePalette {
    fileprivate init(colors: FormaColorPalette, colorScheme: ColorScheme) {
        let themeColors = ThemeColorProvider.colors(from: colors, colorScheme: colorScheme)
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
            previewSwatchAccent: colors.accent,
            previewSwatchSurface: colors.surfaceElevated,
            previewSwatchCanvas: colors.canvas
        )
    }
}
