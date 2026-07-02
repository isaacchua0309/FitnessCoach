//
//  FormaPaletteContrastAudit.swift
//  Fitness CoachTests
//
//  Forma — WCAG contrast audit helpers for palette validation.
//

import SwiftUI
@testable import Fitness_Coach

enum FormaPaletteContrastAudit {

    enum TextRole {
        case primary
        case secondary

        var minimumRatioOnCanvas: CGFloat {
            switch self {
            case .primary: 4.5
            case .secondary: 3.0
            }
        }

        var minimumRatioOnSurface: CGFloat {
            switch self {
            case .primary: 4.5
            case .secondary: 4.5
            }
        }
    }

    struct Finding: Equatable, CustomStringConvertible {
        let palette: AppThemePalette
        let colorScheme: ColorScheme
        let pair: String
        let ratio: CGFloat
        let minimum: CGFloat

        var description: String {
            "\(palette.rawValue) \(colorScheme) — \(pair): \(String(format: "%.2f", ratio)):1 (min \(minimum):1)"
        }
    }

    static func blended(_ overlay: Color, over background: Color) -> Color {
        let overlayRGBA = FormaColorContrast.rgbaComponents(for: overlay)
        let backgroundRGBA = FormaColorContrast.rgbaComponents(for: background)
        let alpha = overlayRGBA.alpha
        let inverseAlpha = 1 - alpha
        return Color(
            red: overlayRGBA.red * alpha + backgroundRGBA.red * inverseAlpha,
            green: overlayRGBA.green * alpha + backgroundRGBA.green * inverseAlpha,
            blue: overlayRGBA.blue * alpha + backgroundRGBA.blue * inverseAlpha,
            opacity: 1
        )
    }

    static func surfaceBackground(for palette: FormaColorPalette) -> Color {
        blended(palette.surface, over: palette.canvas)
    }

    static func selectedBackground(for palette: FormaColorPalette) -> Color {
        blended(palette.selectedBackground, over: palette.canvas)
    }

    static func chartBackground(for palette: FormaColorPalette) -> Color {
        blended(palette.progressTrack, over: palette.canvas)
    }

    static func auditAllPalettes() -> [Finding] {
        var findings: [Finding] = []

        for themePalette in FormaPaletteCatalog.registeredThemePalettes {
            for colorScheme in FormaPaletteCatalog.registeredColorSchemes {
                let palette = FormaPaletteCatalog.palette(for: themePalette, colorScheme: colorScheme)
                findings.append(contentsOf: audit(palette: palette, themePalette: themePalette, colorScheme: colorScheme))
            }
        }

        return findings
    }

    static func audit(
        palette: FormaColorPalette,
        themePalette: AppThemePalette,
        colorScheme: ColorScheme
    ) -> [Finding] {
        var findings: [Finding] = []
        let surface = surfaceBackground(for: palette)
        let selected = selectedBackground(for: palette)
        let chartBackground = chartBackground(for: palette)

        func record(
            _ pair: String,
            foreground: Color,
            background: Color,
            minimum: CGFloat
        ) {
            let ratio = FormaColorContrast.contrastRatio(foreground: foreground, background: background)
            if ratio < minimum {
                findings.append(
                    Finding(
                        palette: themePalette,
                        colorScheme: colorScheme,
                        pair: pair,
                        ratio: ratio,
                        minimum: minimum
                    )
                )
            }
        }

        for role in [TextRole.primary, TextRole.secondary] {
            let text = role == .primary ? palette.textPrimary : palette.textSecondary
            record(
                "text\(role == .primary ? "Primary" : "Secondary") on canvas",
                foreground: text,
                background: palette.canvas,
                minimum: role.minimumRatioOnCanvas
            )
            record(
                "text\(role == .primary ? "Primary" : "Secondary") on surface",
                foreground: text,
                background: surface,
                minimum: role.minimumRatioOnSurface
            )
        }

        record(
            "ctaText on ctaBackground",
            foreground: palette.ctaText,
            background: palette.ctaBackground,
            minimum: 4.5
        )

        record(
            "accent on canvas",
            foreground: palette.accent,
            background: palette.canvas,
            minimum: 3.0
        )

        record(
            "chartPrimary on chart background",
            foreground: palette.chartPrimary,
            background: chartBackground,
            minimum: 3.0
        )

        record(
            "textPrimary on selected background",
            foreground: palette.textPrimary,
            background: selected,
            minimum: 4.5
        )

        record(
            "selectedBorder on selected background",
            foreground: palette.selectedBorder,
            background: selected,
            minimum: 1.5
        )

        let theme = ThemePaletteCatalog.palette(for: themePalette, colorScheme: colorScheme)
        let pickerSelectedBackground = FormaPaletteContrastAudit.blended(
            theme.softBackground,
            over: palette.canvas
        )
        let pickerUnselectedBackground = FormaPaletteContrastAudit.blended(
            palette.surfaceSubtle,
            over: palette.canvas
        )

        record(
            "textPrimary on theme picker selected background",
            foreground: palette.textPrimary,
            background: pickerSelectedBackground,
            minimum: 4.5
        )

        record(
            "textSecondary on theme picker selected background",
            foreground: palette.textSecondary,
            background: pickerSelectedBackground,
            minimum: 4.5
        )

        record(
            "textPrimary on theme picker unselected background",
            foreground: palette.textPrimary,
            background: pickerUnselectedBackground,
            minimum: 4.5
        )

        record(
            "theme primary border on theme picker unselected background",
            foreground: theme.primary.opacity(0.88),
            background: pickerUnselectedBackground,
            minimum: 2.0
        )

        record(
            "textOnAccent on primary button background",
            foreground: theme.textOnAccent,
            background: theme.primaryButtonBackground,
            minimum: 4.5
        )

        return findings
    }
}
