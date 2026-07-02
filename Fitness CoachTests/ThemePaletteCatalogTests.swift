//
//  ThemePaletteCatalogTests.swift
//  Fitness CoachTests
//
//  Forma — Canonical ThemePalette catalog coverage.
//

import SwiftUI
import XCTest
@testable import Fitness_Coach

final class ThemePaletteCatalogTests: XCTestCase {

    func testEveryRegisteredPaletteHasRequiredTokens() {
        for paletteID in ThemePaletteCatalog.registeredPalettes {
            for scheme in [ColorScheme.dark, ColorScheme.light] {
                let palette = ThemePaletteCatalog.palette(for: paletteID, colorScheme: scheme)
                XCTAssertEqual(palette.id, paletteID)
                XCTAssertFalse(palette.displayName.isEmpty)
                XCTAssertFalse(palette.subtitle.isEmpty)
                XCTAssertFalse(palette.iconSymbol.isEmpty)
                XCTAssertGreaterThan(FormaColorContrast.alpha(palette.primary), 0.9)
                XCTAssertGreaterThan(FormaColorContrast.alpha(palette.textOnAccent), 0.9)
            }
        }
    }

    func testOceanBlueAnchorsMatchSpecification() {
        let palette = ThemePaletteCatalog.palette(for: .oceanBlue, colorScheme: .dark)
        assertColor(palette.primary, red: 59.0 / 255.0, green: 130.0 / 255.0, blue: 246.0 / 255.0)
        assertColor(palette.secondary, red: 96.0 / 255.0, green: 165.0 / 255.0, blue: 250.0 / 255.0)
        assertColor(palette.accent, red: 147.0 / 255.0, green: 197.0 / 255.0, blue: 253.0 / 255.0)
        assertColor(palette.gradientStart, red: 37.0 / 255.0, green: 99.0 / 255.0, blue: 235.0 / 255.0)
        assertColor(palette.gradientEnd, red: 96.0 / 255.0, green: 165.0 / 255.0, blue: 250.0 / 255.0)
        XCTAssertEqual(palette.iconSymbol, "water.waves")
    }

    func testFormaColorPaletteMapsThemeTokens() {
        let theme = ThemePaletteCatalog.palette(for: .emeraldGreen, colorScheme: .dark)
        let colors = FormaPaletteCatalog.formaColorPalette(from: theme, colorScheme: .dark)

        XCTAssertEqual(colors.accent, theme.primary)
        XCTAssertEqual(colors.chartSecondary, theme.secondary)
        XCTAssertEqual(colors.ctaBackground, theme.gradientStart)
        XCTAssertEqual(colors.ctaText, theme.textOnAccent)
        XCTAssertEqual(colors.progress, theme.primary)
        XCTAssertEqual(colors.accentMuted, theme.softBackground)
    }

    private func assertColor(
        _ color: Color,
        red: CGFloat,
        green: CGFloat,
        blue: CGFloat,
        accuracy: CGFloat = 0.015
    ) {
        let components = FormaColorContrast.rgbaComponents(for: color)
        XCTAssertEqual(components.red, red, accuracy: accuracy)
        XCTAssertEqual(components.green, green, accuracy: accuracy)
        XCTAssertEqual(components.blue, blue, accuracy: accuracy)
    }
}
