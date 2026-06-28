//
//  PublicWelcomeTheme.swift
//  Fitness Coach
//
//  Forma — Adaptive palette for the public welcome screen (light-first).
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
        var accentForeground: Color
        var textPrimary: Color
        var textSecondary: Color
        var textTertiary: Color
        var chipBackground: Color
        var chipIconBackground: Color
    }

    static func palette(colorScheme: ColorScheme) -> Palette {
        switch colorScheme {
        case .dark:
            return Palette(
                canvas: Color(red: 0.05, green: 0.07, blue: 0.10),
                canvasGlow: Color(red: 0.16, green: 0.48, blue: 0.54).opacity(0.22),
                surface: Color.white.opacity(0.06),
                surfaceBorder: Color.white.opacity(0.10),
                accent: Color(red: 0.34, green: 0.74, blue: 0.78),
                accentSoft: Color(red: 0.34, green: 0.74, blue: 0.78).opacity(0.16),
                accentForeground: Color(red: 0.04, green: 0.10, blue: 0.12),
                textPrimary: Color.white,
                textSecondary: Color.white.opacity(0.72),
                textTertiary: Color.white.opacity(0.50),
                chipBackground: Color.white.opacity(0.05),
                chipIconBackground: Color(red: 0.34, green: 0.74, blue: 0.78).opacity(0.18)
            )
        default:
            return Palette(
                canvas: Color(red: 0.98, green: 0.98, blue: 0.96),
                canvasGlow: Color(red: 0.20, green: 0.58, blue: 0.62).opacity(0.14),
                surface: Color.white,
                surfaceBorder: Color(red: 0.86, green: 0.90, blue: 0.91),
                accent: Color(red: 0.12, green: 0.52, blue: 0.58),
                accentSoft: Color(red: 0.12, green: 0.52, blue: 0.58).opacity(0.10),
                accentForeground: Color.white,
                textPrimary: Color(red: 0.10, green: 0.13, blue: 0.16),
                textSecondary: Color(red: 0.28, green: 0.33, blue: 0.38),
                textTertiary: Color(red: 0.45, green: 0.50, blue: 0.55),
                chipBackground: Color.white,
                chipIconBackground: Color(red: 0.12, green: 0.52, blue: 0.58).opacity(0.10)
            )
        }
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
                    .clear
                ],
                center: .top,
                startRadius: 8,
                endRadius: 420
            )

            LinearGradient(
                colors: [
                    palette.accentSoft.opacity(0.55),
                    .clear
                ],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.38)
            )
        }
        .ignoresSafeArea()
    }
}
