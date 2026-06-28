//
//  FormaThemePalette.swift
//  Fitness Coach
//
//  Forma — Legacy theme palette resolved from FormaPaletteCatalog.
//

import SwiftUI

struct FormaThemePalette: Equatable, Sendable {
    let canvas: Color
    let surface: Color
    let surfaceElevated: Color
    let surfaceSubtle: Color
    let border: Color
    let borderStrong: Color
    let borderSelected: Color
    let accent: Color
    let accentMuted: Color
    let textPrimary: Color
    let textSecondary: Color
    let textTertiary: Color
    let textLegal: Color
    let destructive: Color
    let warning: Color
    let success: Color
    let googleButtonBackground: Color
    let googleButtonText: Color
    let googleButtonBorder: Color
    let previewSwatchAccent: Color
    let previewSwatchSurface: Color
    let previewSwatchCanvas: Color

    var previewSwatches: [Color] {
        [previewSwatchAccent, previewSwatchSurface, previewSwatchCanvas]
    }

    static func palette(for colorTheme: FormaColorPaletteID, colorScheme: ColorScheme) -> FormaThemePalette {
        FormaPaletteCatalog.legacyThemePalette(for: colorTheme, colorScheme: colorScheme)
    }

    static let defaultDarkForma = palette(for: .defaultForma, colorScheme: .dark)
}

private struct FormaThemePaletteKey: EnvironmentKey {
    static let defaultValue = FormaThemePalette.defaultDarkForma
}

extension EnvironmentValues {
    var formaThemePalette: FormaThemePalette {
        get { self[FormaThemePaletteKey.self] }
        set { self[FormaThemePaletteKey.self] = newValue }
    }
}
