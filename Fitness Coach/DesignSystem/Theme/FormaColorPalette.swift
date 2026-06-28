//
//  FormaColorPalette.swift
//  Fitness Coach
//
//  Forma — Resolved semantic color tokens for a theme.
//

import SwiftUI

struct FormaColorPalette: Equatable, Sendable {
    let canvas: Color
    let background: Color
    let surface: Color
    let surfaceElevated: Color
    let surfaceSubtle: Color
    let border: Color
    let borderStrong: Color
    let borderSelected: Color
    let accent: Color
    let accentPrimary: Color
    let accentSecondary: Color
    let accentMuted: Color
    let textPrimary: Color
    let textSecondary: Color
    let textTertiary: Color
    let ctaBackground: Color
    let ctaText: Color
    let progress: Color
    let progressTrack: Color
    let selectedBackground: Color
    let selectedBorder: Color
    let chartPrimary: Color
    let chartSecondary: Color
    let success: Color
    let warning: Color
    let destructive: Color
    let shadow: Color

    /// All required semantic tokens for validation and tests.
    var semanticTokens: [String: Color] {
        [
            "canvas": canvas,
            "background": background,
            "surface": surface,
            "surfaceElevated": surfaceElevated,
            "surfaceSubtle": surfaceSubtle,
            "border": border,
            "borderStrong": borderStrong,
            "borderSelected": borderSelected,
            "accent": accent,
            "accentPrimary": accentPrimary,
            "accentSecondary": accentSecondary,
            "accentMuted": accentMuted,
            "textPrimary": textPrimary,
            "textSecondary": textSecondary,
            "textTertiary": textTertiary,
            "ctaBackground": ctaBackground,
            "ctaText": ctaText,
            "progress": progress,
            "progressTrack": progressTrack,
            "selectedBackground": selectedBackground,
            "selectedBorder": selectedBorder,
            "chartPrimary": chartPrimary,
            "chartSecondary": chartSecondary,
            "success": success,
            "warning": warning,
            "destructive": destructive,
            "shadow": shadow
        ]
    }

    /// Preview swatch colors for Settings palette rows.
    var previewSwatches: [Color] {
        [accent, surfaceElevated, canvas]
    }
}

enum FormaColorPaletteCatalog {

    static func palette(
        for themePalette: AppThemePalette,
        colorScheme: ColorScheme
    ) -> FormaColorPalette {
        FormaPaletteCatalog.palette(for: themePalette, colorScheme: colorScheme)
    }

    static let defaultDark = FormaPaletteCatalog.defaultDark
}
