//
//  FormaPaletteCatalogTests.swift
//  Fitness CoachTests
//
//  Forma — Registered palette catalog coverage and accessibility sanity checks.
//

import SwiftUI
import XCTest
@testable import Fitness_Coach

final class FormaPaletteCatalogTests: XCTestCase {

    private let requiredTokenKeys: [String] = [
        "canvas",
        "background",
        "surface",
        "surfaceElevated",
        "surfaceSubtle",
        "border",
        "borderStrong",
        "borderSelected",
        "accent",
        "accentPrimary",
        "accentSecondary",
        "accentMuted",
        "textPrimary",
        "textSecondary",
        "textTertiary",
        "ctaBackground",
        "ctaText",
        "progress",
        "progressTrack",
        "selectedBackground",
        "selectedBorder",
        "chartPrimary",
        "chartSecondary",
        "gradientStart",
        "gradientEnd",
        "success",
        "warning",
        "destructive",
        "shadow"
    ]

    // MARK: - Coverage

    func testEveryPaletteHasLightAndDarkVariants() {
        for themePalette in FormaPaletteCatalog.registeredThemePalettes {
            for colorScheme in FormaPaletteCatalog.registeredColorSchemes {
                let palette = FormaPaletteCatalog.palette(for: themePalette, colorScheme: colorScheme)
                XCTAssertFalse(palette.semanticTokens.isEmpty)
            }
        }

        XCTAssertEqual(FormaPaletteCatalog.registeredThemePalettes.count, AppThemePalette.allCases.count)
        XCTAssertEqual(FormaPaletteCatalog.registeredColorSchemes.count, 2)
    }

    func testEveryRequiredSemanticTokenIsPopulated() {
        for themePalette in FormaPaletteCatalog.registeredThemePalettes {
            for colorScheme in FormaPaletteCatalog.registeredColorSchemes {
                let palette = FormaPaletteCatalog.palette(for: themePalette, colorScheme: colorScheme)
                XCTAssertEqual(Set(palette.semanticTokens.keys), Set(requiredTokenKeys))

                for key in requiredTokenKeys {
                    XCTAssertNotNil(
                        palette.semanticTokens[key],
                        "Missing token \(key) for \(themePalette.rawValue) \(colorScheme)"
                    )
                }
            }
        }
    }

    // MARK: - Production baseline

    func testOceanBlueDarkMatchesSpecifiedPrimaryColor() {
        let palette = FormaPaletteCatalog.defaultDark

        assertColor(palette.accent, red: 59.0 / 255.0, green: 130.0 / 255.0, blue: 246.0 / 255.0)
        assertColor(palette.ctaBackground, red: 37.0 / 255.0, green: 99.0 / 255.0, blue: 235.0 / 255.0)
        assertColor(palette.chartSecondary, red: 96.0 / 255.0, green: 165.0 / 255.0, blue: 250.0 / 255.0)
        assertColor(palette.gradientStart, red: 37.0 / 255.0, green: 99.0 / 255.0, blue: 235.0 / 255.0)
        assertColor(palette.gradientEnd, red: 96.0 / 255.0, green: 165.0 / 255.0, blue: 250.0 / 255.0)
        assertColor(palette.textPrimary, red: 1.0, green: 1.0, blue: 1.0)
    }

    // MARK: - Readability

    func testPrimaryTextIsOpaqueOnEveryPalette() {
        for themePalette in FormaPaletteCatalog.registeredThemePalettes {
            for colorScheme in FormaPaletteCatalog.registeredColorSchemes {
                let palette = FormaPaletteCatalog.palette(for: themePalette, colorScheme: colorScheme)
                XCTAssertGreaterThanOrEqual(
                    FormaColorContrast.alpha(palette.textPrimary),
                    0.95,
                    "textPrimary too transparent for \(themePalette.rawValue) \(colorScheme)"
                )
                XCTAssertGreaterThanOrEqual(
                    FormaColorContrast.contrastRatio(foreground: palette.textPrimary, background: palette.canvas),
                    4.5,
                    "textPrimary contrast too low on canvas for \(themePalette.rawValue) \(colorScheme)"
                )
            }
        }
    }

    func testCTATextContrastMeetsWCAGAA() {
        for themePalette in FormaPaletteCatalog.registeredThemePalettes {
            for colorScheme in FormaPaletteCatalog.registeredColorSchemes {
                let palette = FormaPaletteCatalog.palette(for: themePalette, colorScheme: colorScheme)
                let ratio = FormaColorContrast.contrastRatio(
                    foreground: palette.ctaText,
                    background: palette.ctaBackground
                )
                XCTAssertGreaterThanOrEqual(
                    ratio,
                    4.5,
                    "CTA contrast \(ratio) failed for \(themePalette.rawValue) \(colorScheme)"
                )
            }
        }
    }

    func testChartColorsAreDistinctFromCanvas() {
        for themePalette in FormaPaletteCatalog.registeredThemePalettes {
            for colorScheme in FormaPaletteCatalog.registeredColorSchemes {
                let palette = FormaPaletteCatalog.palette(for: themePalette, colorScheme: colorScheme)
                XCTAssertGreaterThan(
                    colorDistance(palette.chartPrimary, palette.canvas),
                    0.08,
                    "chartPrimary too close to canvas for \(themePalette.rawValue) \(colorScheme)"
                )
                XCTAssertGreaterThan(
                    colorDistance(palette.chartSecondary, palette.canvas),
                    0.06,
                    "chartSecondary too close to canvas for \(themePalette.rawValue) \(colorScheme)"
                )
            }
        }
    }

    func testSelectedStatesUseBorderAndFillDistinctly() {
        for themePalette in FormaPaletteCatalog.registeredThemePalettes {
            for colorScheme in FormaPaletteCatalog.registeredColorSchemes {
                let palette = FormaPaletteCatalog.palette(for: themePalette, colorScheme: colorScheme)
                XCTAssertNotEqual(palette.selectedBackground, palette.selectedBorder)
                XCTAssertGreaterThan(
                    FormaColorContrast.alpha(palette.selectedBorder),
                    FormaColorContrast.alpha(palette.selectedBackground),
                    "selected border should be more opaque than fill for \(themePalette.rawValue) \(colorScheme)"
                )
                XCTAssertGreaterThan(
                    FormaColorContrast.alpha(palette.selectedBorder),
                    0.5,
                    "selected border should be clearly visible for \(themePalette.rawValue) \(colorScheme)"
                )
                XCTAssertLessThan(
                    FormaColorContrast.alpha(palette.selectedBackground),
                    0.3,
                    "selected fill should read as a tint for \(themePalette.rawValue) \(colorScheme)"
                )
            }
        }
    }

    func testThemeDarkCanvasesAreDistinct() {
        let oceanCanvas = FormaPaletteCatalog.palette(for: .oceanBlue, colorScheme: .dark).canvas
        let blossomCanvas = FormaPaletteCatalog.palette(for: .blossomPink, colorScheme: .dark).canvas
        let emeraldCanvas = FormaPaletteCatalog.palette(for: .emeraldGreen, colorScheme: .dark).canvas
        let sunsetCanvas = FormaPaletteCatalog.palette(for: .sunsetOrange, colorScheme: .dark).canvas

        XCTAssertGreaterThan(colorDistance(oceanCanvas, blossomCanvas), 0.03)
        XCTAssertGreaterThan(colorDistance(oceanCanvas, emeraldCanvas), 0.02)
        XCTAssertGreaterThan(colorDistance(blossomCanvas, sunsetCanvas), 0.03)
    }

    func testSecondaryTextReadableOnLightSurfaces() {
        for themePalette in FormaPaletteCatalog.registeredThemePalettes {
            let palette = FormaPaletteCatalog.palette(for: themePalette, colorScheme: .light)
            let surfaceBackground = blendedOverCanvas(palette.surface, canvas: palette.canvas)
            let ratio = FormaColorContrast.contrastRatio(
                foreground: palette.textSecondary,
                background: surfaceBackground
            )
            XCTAssertGreaterThanOrEqual(
                ratio,
                4.5,
                "textSecondary contrast too low on surface for \(themePalette.rawValue) light"
            )
        }
    }

    func testLightBordersAreVisibleButSubtleOnCanvas() {
        for themePalette in FormaPaletteCatalog.registeredThemePalettes {
            let palette = FormaPaletteCatalog.palette(for: themePalette, colorScheme: .light)
            let renderedBorder = blendedOverCanvas(palette.border, canvas: palette.canvas)
            let contrast = FormaColorContrast.contrastRatio(
                foreground: renderedBorder,
                background: palette.canvas
            )
            XCTAssertGreaterThan(
                contrast,
                1.08,
                "border too faint on canvas for \(themePalette.rawValue) light"
            )
            XCTAssertLessThan(
                contrast,
                1.35,
                "border too heavy on canvas for \(themePalette.rawValue) light"
            )
        }
    }

    func testChartColorsRemainDistinctOnLightPalettes() {
        for themePalette in FormaPaletteCatalog.registeredThemePalettes {
            let palette = FormaPaletteCatalog.palette(for: themePalette, colorScheme: .light)
            XCTAssertNotEqual(palette.chartPrimary, palette.chartSecondary)
            XCTAssertGreaterThan(
                abs(
                    FormaColorContrast.alpha(palette.chartPrimary)
                        - FormaColorContrast.alpha(palette.chartSecondary)
                ),
                0.05,
                "chart secondary should read lighter than primary for \(themePalette.rawValue) light"
            )
            XCTAssertGreaterThan(
                colorDistance(palette.chartPrimary, palette.canvas),
                0.08,
                "chartPrimary too close to canvas for \(themePalette.rawValue) light"
            )
        }
    }

    // MARK: - Helpers

    private func assertColor(
        _ color: Color,
        red: CGFloat,
        green: CGFloat,
        blue: CGFloat,
        alpha: CGFloat = 1.0,
        accuracy: CGFloat = 0.015,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let components = FormaColorContrast.rgbaComponents(for: color)
        XCTAssertEqual(components.red, red, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(components.green, green, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(components.blue, blue, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(components.alpha, alpha, accuracy: accuracy, file: file, line: line)
    }

    private func colorDistance(_ lhs: Color, _ rhs: Color) -> CGFloat {
        let a = FormaColorContrast.rgbaComponents(for: lhs)
        let b = FormaColorContrast.rgbaComponents(for: rhs)
        let deltaRed = a.red - b.red
        let deltaGreen = a.green - b.green
        let deltaBlue = a.blue - b.blue
        return sqrt(deltaRed * deltaRed + deltaGreen * deltaGreen + deltaBlue * deltaBlue)
    }

    private func blendedOverCanvas(_ overlay: Color, canvas: Color) -> Color {
        let overlayRGBA = FormaColorContrast.rgbaComponents(for: overlay)
        let canvasRGBA = FormaColorContrast.rgbaComponents(for: canvas)
        let alpha = overlayRGBA.alpha
        let inverseAlpha = 1 - alpha
        return Color(
            red: overlayRGBA.red * alpha + canvasRGBA.red * inverseAlpha,
            green: overlayRGBA.green * alpha + canvasRGBA.green * inverseAlpha,
            blue: overlayRGBA.blue * alpha + canvasRGBA.blue * inverseAlpha,
            opacity: 1
        )
    }
}
