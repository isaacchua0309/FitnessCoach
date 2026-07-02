//
//  NeutralAppearanceColors.swift
//  Fitness Coach
//
//  Forma — Appearance-based structural colors that do not vary by user theme palette.
//

import SwiftUI

/// Canvas, ink, and shadow values shared across all user-selectable theme palettes.
enum NeutralAppearanceColors {

    struct Palette: Equatable, Sendable {
        let canvas: Color
        let background: Color
        let textPrimary: Color
        let textSecondary: Color
        let textTertiary: Color
        let shadow: Color
    }

    static func palette(for colorScheme: ColorScheme) -> Palette {
        colorScheme == .dark ? dark : light
    }

    // MARK: - Dark

    private static let dark = Palette(
        canvas: C.rgb(0.04, 0.04, 0.05),
        background: C.rgb(0.04, 0.04, 0.05),
        textPrimary: C.rgb(1.0, 1.0, 1.0),
        textSecondary: C.rgb(1.0, 1.0, 1.0, opacity: 0.68),
        textTertiary: C.rgb(1.0, 1.0, 1.0, opacity: 0.48),
        shadow: C.rgb(0.0, 0.0, 0.0, opacity: 0.35)
    )

    // MARK: - Light

    private static let light = Palette(
        canvas: C.rgb(0.97, 0.97, 0.98),
        background: C.rgb(0.97, 0.97, 0.98),
        textPrimary: C.rgb(0.08, 0.09, 0.11),
        textSecondary: C.rgb(0.08, 0.09, 0.11, opacity: 0.68),
        textTertiary: C.rgb(0.08, 0.09, 0.11, opacity: 0.48),
        shadow: C.rgb(0.0, 0.0, 0.0, opacity: 0.12)
    )
}

// MARK: - Primitives (neutral catalog only)

private enum C {
    static func rgb(_ red: Double, _ green: Double, _ blue: Double, opacity: Double = 1.0) -> Color {
        Color(red: red, green: green, blue: blue, opacity: opacity)
    }
}
