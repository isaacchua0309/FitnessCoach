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
        switch themePalette {
        case .oceanBlue:
            return colorScheme == .dark ? oceanBlueDark : oceanBlueLight
        case .blossomPink:
            return colorScheme == .dark ? blossomPinkDark : blossomPinkLight
        case .emeraldGreen:
            return colorScheme == .dark ? emeraldGreenDark : emeraldGreenLight
        case .sunsetOrange:
            return colorScheme == .dark ? sunsetOrangeDark : sunsetOrangeLight
        }
    }

    /// Default palette for the dark color scheme.
    static var defaultDark: FormaColorPalette { oceanBlueDark }

    // MARK: - Ocean Blue

    private static let oceanBlueDark = makeDarkPalette(
        canvas: C.hex(0x070D1A),
        surfaceTint: C.hex(0x60A5FA),
        anchors: ThemeColorAnchors(
            primary: C.hex(0x3B82F6),
            secondary: C.hex(0x60A5FA),
            accent: C.hex(0x93C5FD),
            gradientStart: C.hex(0x2563EB),
            gradientEnd: C.hex(0x60A5FA)
        ),
        ctaText: C.rgb(1.0, 1.0, 1.0),
        feedback: .dark
    )

    private static let oceanBlueLight = makeLightPalette(
        canvas: C.hex(0xF5F8FF),
        ink: C.hex(0x0B1220),
        anchors: ThemeColorAnchors(
            primary: C.hex(0x3B82F6),
            secondary: C.hex(0x60A5FA),
            accent: C.hex(0x93C5FD),
            gradientStart: C.hex(0x2563EB),
            gradientEnd: C.hex(0x60A5FA)
        ),
        ctaText: C.rgb(1.0, 1.0, 1.0),
        feedback: .light
    )

    // MARK: - Blossom Pink

    private static let blossomPinkDark = makeDarkPalette(
        canvas: C.hex(0x1A0A12),
        surfaceTint: C.hex(0xF472B6),
        anchors: ThemeColorAnchors(
            primary: C.hex(0xEC4899),
            secondary: C.hex(0xF472B6),
            accent: C.hex(0xF9A8D4),
            gradientStart: C.hex(0xDB2777),
            gradientEnd: C.hex(0xF472B6)
        ),
        ctaText: C.rgb(1.0, 1.0, 1.0),
        feedback: .dark
    )

    private static let blossomPinkLight = makeLightPalette(
        canvas: C.hex(0xFFF5F9),
        ink: C.hex(0x1A0A12),
        anchors: ThemeColorAnchors(
            primary: C.hex(0xEC4899),
            secondary: C.hex(0xF472B6),
            accent: C.hex(0xF9A8D4),
            gradientStart: C.hex(0xDB2777),
            gradientEnd: C.hex(0xF472B6)
        ),
        ctaText: C.rgb(1.0, 1.0, 1.0),
        feedback: .light
    )

    // MARK: - Emerald Green

    private static let emeraldGreenDark = makeDarkPalette(
        canvas: C.hex(0x071510),
        surfaceTint: C.hex(0x34D399),
        anchors: ThemeColorAnchors(
            primary: C.hex(0x10B981),
            secondary: C.hex(0x34D399),
            accent: C.hex(0x6EE7B7),
            gradientStart: C.hex(0x059669),
            gradientEnd: C.hex(0x34D399)
        ),
        ctaText: C.rgb(1.0, 1.0, 1.0),
        feedback: .dark
    )

    private static let emeraldGreenLight = makeLightPalette(
        canvas: C.hex(0xF0FDF8),
        ink: C.hex(0x071510),
        anchors: ThemeColorAnchors(
            primary: C.hex(0x10B981),
            secondary: C.hex(0x34D399),
            accent: C.hex(0x6EE7B7),
            gradientStart: C.hex(0x059669),
            gradientEnd: C.hex(0x34D399)
        ),
        ctaText: C.rgb(1.0, 1.0, 1.0),
        feedback: .light
    )

    // MARK: - Sunset Orange

    private static let sunsetOrangeDark = makeDarkPalette(
        canvas: C.hex(0x1A0E07),
        surfaceTint: C.hex(0xFB923C),
        anchors: ThemeColorAnchors(
            primary: C.hex(0xF97316),
            secondary: C.hex(0xFB923C),
            accent: C.hex(0xFDBA74),
            gradientStart: C.hex(0xEA580C),
            gradientEnd: C.hex(0xFB923C)
        ),
        ctaText: C.rgb(1.0, 1.0, 1.0),
        feedback: .dark
    )

    private static let sunsetOrangeLight = makeLightPalette(
        canvas: C.hex(0xFFF7ED),
        ink: C.hex(0x1A0E07),
        anchors: ThemeColorAnchors(
            primary: C.hex(0xF97316),
            secondary: C.hex(0xFB923C),
            accent: C.hex(0xFDBA74),
            gradientStart: C.hex(0xEA580C),
            gradientEnd: C.hex(0xFB923C)
        ),
        ctaText: C.rgb(1.0, 1.0, 1.0),
        feedback: .light
    )

    // MARK: - Legacy theme palette bridge

    static func legacyThemePalette(
        for themePalette: AppThemePalette,
        colorScheme: ColorScheme
    ) -> FormaThemePalette {
        let colors = palette(for: themePalette, colorScheme: colorScheme)
        return FormaThemePalette(colors: colors, colorScheme: colorScheme)
    }

    // MARK: - Builders

    private struct ThemeColorAnchors {
        let primary: Color
        let secondary: Color
        let accent: Color
        let gradientStart: Color
        let gradientEnd: Color
    }

    private static func makeDarkPalette(
        canvas: Color,
        surfaceTint: Color,
        anchors: ThemeColorAnchors,
        ctaText: Color,
        feedback: FeedbackPalette
    ) -> FormaColorPalette {
        let surface = surfaceTint.opacity(0.07)
        let surfaceElevated = surfaceTint.opacity(0.10)
        let surfaceSubtle = surfaceTint.opacity(0.05)
        let border = surfaceTint.opacity(0.12)
        let borderStrong = surfaceTint.opacity(0.20)
        let textPrimary = C.rgb(1.0, 1.0, 1.0)
        let textSecondary = textPrimary.opacity(0.68)
        let textTertiary = textPrimary.opacity(0.48)
        let accentMuted = anchors.accent.opacity(0.16)
        let borderSelected = anchors.primary.opacity(0.72)

        return FormaColorPalette(
            canvas: canvas,
            background: canvas,
            surface: surface,
            surfaceElevated: surfaceElevated,
            surfaceSubtle: surfaceSubtle,
            border: border,
            borderStrong: borderStrong,
            borderSelected: borderSelected,
            accent: anchors.primary,
            accentPrimary: anchors.primary,
            accentSecondary: anchors.secondary,
            accentMuted: accentMuted,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            textTertiary: textTertiary,
            ctaBackground: anchors.gradientStart,
            ctaText: ctaText,
            progress: anchors.primary,
            progressTrack: surfaceSubtle,
            selectedBackground: accentMuted,
            selectedBorder: borderSelected,
            chartPrimary: anchors.primary,
            chartSecondary: anchors.secondary,
            gradientStart: anchors.gradientStart,
            gradientEnd: anchors.gradientEnd,
            success: feedback.success,
            warning: feedback.warning,
            destructive: feedback.destructive,
            shadow: C.rgb(0.0, 0.0, 0.0, opacity: 0.35)
        )
    }

    private static func makeLightPalette(
        canvas: Color,
        ink: Color,
        anchors: ThemeColorAnchors,
        ctaText: Color,
        feedback: FeedbackPalette
    ) -> FormaColorPalette {
        let surface = ink.opacity(0.05)
        let surfaceElevated = ink.opacity(0.08)
        let surfaceSubtle = ink.opacity(0.03)
        let border = ink.opacity(0.10)
        let borderStrong = ink.opacity(0.18)
        let textPrimary = ink
        let textSecondary = ink.opacity(0.68)
        let textTertiary = ink.opacity(0.48)
        let accentMuted = anchors.accent.opacity(0.14)
        let borderSelected = anchors.primary.opacity(0.72)

        return FormaColorPalette(
            canvas: canvas,
            background: canvas,
            surface: surface,
            surfaceElevated: surfaceElevated,
            surfaceSubtle: surfaceSubtle,
            border: border,
            borderStrong: borderStrong,
            borderSelected: borderSelected,
            accent: anchors.primary,
            accentPrimary: anchors.primary,
            accentSecondary: anchors.secondary,
            accentMuted: accentMuted,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            textTertiary: textTertiary,
            ctaBackground: anchors.gradientStart,
            ctaText: ctaText,
            progress: anchors.primary,
            progressTrack: surfaceSubtle,
            selectedBackground: accentMuted,
            selectedBorder: borderSelected,
            chartPrimary: anchors.primary,
            chartSecondary: anchors.secondary,
            gradientStart: anchors.gradientStart,
            gradientEnd: anchors.gradientEnd,
            success: feedback.success,
            warning: feedback.warning,
            destructive: feedback.destructive,
            shadow: C.rgb(0.0, 0.0, 0.0, opacity: 0.12)
        )
    }
}

// MARK: - Primitives (catalog-internal only)

private enum C {
    static func rgb(_ red: Double, _ green: Double, _ blue: Double, opacity: Double = 1.0) -> Color {
        Color(red: red, green: green, blue: blue, opacity: opacity)
    }

    static func hex(_ value: UInt32) -> Color {
        let red = Double((value >> 16) & 0xFF) / 255.0
        let green = Double((value >> 8) & 0xFF) / 255.0
        let blue = Double(value & 0xFF) / 255.0
        return Color(red: red, green: green, blue: blue)
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
