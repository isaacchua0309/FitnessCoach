//
//  PublicWelcomeTheme.swift
//  Fitness Coach
//
//  Forma — Shared palette for public entry screens (resolved Forma theme).
//

import SwiftUI

enum PublicWelcomeTheme {

    struct Palette: Equatable {
        var canvas: Color
        var canvasGlow: Color
        var surface: Color
        var surfaceBorder: Color
        var accent: Color
        var accentSoft: Color
        var ctaBackground: Color
        var ctaText: Color
        var warning: Color
        var warningSoft: Color
        var textPrimary: Color
        var textSecondary: Color
        var textTertiary: Color
        var chipBackground: Color
        var chipIconBackground: Color

        /// Text on accent-tinted primary CTAs.
        var accentForeground: Color { ctaText }
    }

    /// Builds a public-entry palette from the fully resolved app theme.
    @MainActor
    static func palette(from resolved: ResolvedAppTheme) -> Palette {
        let colors = ThemeColorProvider.colors(from: resolved)
        return Palette(
            canvas: colors.canvas,
            canvasGlow: colors.accent.opacity(0.10),
            surface: colors.surfaceSubtle,
            surfaceBorder: colors.border,
            accent: colors.accent,
            accentSoft: colors.accentMuted,
            ctaBackground: colors.ctaBackground,
            ctaText: colors.ctaText,
            warning: colors.warning,
            warningSoft: colors.warning.opacity(0.14),
            textPrimary: colors.textPrimary,
            textSecondary: colors.textSecondary,
            textTertiary: colors.textTertiary,
            chipBackground: .clear,
            chipIconBackground: colors.accentMuted
        )
    }

    /// Resolves palette for the active theme preferences and the given system color scheme.
    ///
    /// Prefer `palette(from:)` with `@Environment(\.formaResolvedTheme)` in views when possible.
    @MainActor
    static func palette(colorScheme: ColorScheme) -> Palette {
        let preferences = FormaThemeAccess.currentResolvedTheme.preferences
        let resolved = ThemeResolver.resolve(
            preferences: preferences,
            systemColorScheme: colorScheme
        )
        return palette(from: resolved)
    }
}

struct PublicEntryScreenBackground: View {
    let palette: PublicWelcomeTheme.Palette

    var body: some View {
        ZStack {
            palette.canvas

            RadialGradient(
                colors: [
                    palette.canvasGlow,
                    palette.accent.opacity(0.02),
                    .clear
                ],
                center: .top,
                startRadius: 4,
                endRadius: 380
            )

            LinearGradient(
                colors: [
                    palette.accent.opacity(0.03),
                    .clear
                ],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.42)
            )
        }
        .ignoresSafeArea()
    }
}
