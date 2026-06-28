//
//  FormaThemeColors.swift
//  Fitness Coach
//
//  Forma — Semantic color facade for token call sites and static bridges.
//

import SwiftUI

/// Resolved semantic colors for `FormaTokens.Color` and other static access points.
struct FormaThemeColors: Equatable, Sendable {
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
    let ctaBackground: Color
    let ctaText: Color
    let progress: Color
    let progressTrack: Color
    let chartPrimary: Color
    let chartSecondary: Color
    let shadow: Color
    let destructive: Color
    let warning: Color
    let success: Color
    let googleButtonBackground: Color
    let googleButtonForeground: Color
    let googleButtonBorder: Color
    let googleButtonShadow: Color
    let googleButtonShadowLoading: Color

    /// Migration alias — prefer `googleButtonForeground`.
    var googleButtonText: Color { googleButtonForeground }
}
