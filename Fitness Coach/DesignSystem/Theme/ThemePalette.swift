//
//  ThemePalette.swift
//  Fitness Coach
//
//  Forma — Canonical user-selectable theme color tokens (single source of truth).
//

import SwiftUI

/// Resolved theme accent palette for the active color scheme.
///
/// Structural colors (canvas, primary text, destructive, warning) are **not** part of this model.
/// They come from `NeutralAppearanceColors` and shared feedback tokens.
struct ThemePalette: Equatable, Sendable, Identifiable {
    let id: AppThemePalette
    let displayName: String
    let subtitle: String
    let primary: Color
    let secondary: Color
    let accent: Color
    let gradientStart: Color
    let gradientEnd: Color
    let softBackground: Color
    let cardTint: Color
    let borderTint: Color
    let textOnAccent: Color
    /// SF Symbol name shown in theme settings and previews.
    let iconSymbol: String

    /// Primary CTA fill — matches gradient start for button consistency.
    var primaryButtonBackground: Color { gradientStart }

    /// Linear gradient for hero washes and primary buttons.
    var primaryGradient: LinearGradient {
        LinearGradient(
            colors: [gradientStart, gradientEnd],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}
