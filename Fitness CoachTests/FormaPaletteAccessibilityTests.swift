//
//  FormaPaletteAccessibilityTests.swift
//  Fitness CoachTests
//
//  Forma — Comprehensive palette contrast and accessibility sanity checks.
//

import SwiftUI
import XCTest
@testable import Fitness_Coach

final class FormaPaletteAccessibilityTests: XCTestCase {

    // MARK: - Contrast matrix

    func testAllPaletteContrastPairsMeetWCAGMinimums() {
        let failures = FormaPaletteContrastAudit.auditAllPalettes()
        if failures.isEmpty { return }

        let report = failures.map(\.description).joined(separator: "\n")
        XCTFail(
            """
            \(failures.count) palette contrast pair(s) below WCAG minimum:

            \(report)
            """
        )
    }

    func testTextPrimaryOnCanvasMeetsAA() {
        assertPairPasses(
            pair: "textPrimary on canvas",
            minimum: 4.5
        ) { palette, _ in
            (palette.textPrimary, palette.canvas)
        }
    }

    func testTextSecondaryOnCanvasMeetsLargeTextAA() {
        assertPairPasses(
            pair: "textSecondary on canvas",
            minimum: 3.0
        ) { palette, _ in
            (palette.textSecondary, palette.canvas)
        }
    }

    func testTextPrimaryOnSurfaceMeetsAA() {
        assertPairPasses(
            pair: "textPrimary on surface",
            minimum: 4.5
        ) { palette, _ in
            let surface = FormaPaletteContrastAudit.surfaceBackground(for: palette)
            return (palette.textPrimary, surface)
        }
    }

    func testTextSecondaryOnSurfaceMeetsAA() {
        assertPairPasses(
            pair: "textSecondary on surface",
            minimum: 4.5
        ) { palette, _ in
            let surface = FormaPaletteContrastAudit.surfaceBackground(for: palette)
            return (palette.textSecondary, surface)
        }
    }

    func testCTATextOnCTABackgroundMeetsAA() {
        assertPairPasses(
            pair: "ctaText on ctaBackground",
            minimum: 4.5
        ) { palette, _ in
            (palette.ctaText, palette.ctaBackground)
        }
    }

    func testAccentOnCanvasMeetsLargeTextAA() {
        assertPairPasses(
            pair: "accent on canvas",
            minimum: 3.0
        ) { palette, _ in
            (palette.accent, palette.canvas)
        }
    }

    func testChartPrimaryOnChartBackgroundIsLegible() {
        assertPairPasses(
            pair: "chartPrimary on chart background",
            minimum: 3.0
        ) { palette, _ in
            let chartBackground = FormaPaletteContrastAudit.chartBackground(for: palette)
            return (palette.chartPrimary, chartBackground)
        }
    }

    func testSelectedStateTextAndBorderAreLegible() {
        assertPairPasses(
            pair: "textPrimary on selected background",
            minimum: 4.5
        ) { palette, _ in
            let selected = FormaPaletteContrastAudit.selectedBackground(for: palette)
            return (palette.textPrimary, selected)
        }

        assertPairPasses(
            pair: "selectedBorder on selected background",
            minimum: 1.5
        ) { palette, _ in
            let selected = FormaPaletteContrastAudit.selectedBackground(for: palette)
            return (palette.selectedBorder, selected)
        }
    }

    // MARK: - Theme settings accessibility copy

    func testThemeSettingsAppearanceAccessibilityLabelsIncludeSelectionState() {
        XCTAssertEqual(
            AppAppearanceMode.dark.accessibilityLabel(isSelected: true),
            "Dark, selected, Always use dark appearance"
        )
        XCTAssertEqual(
            AppAppearanceMode.light.accessibilityLabel(isSelected: false),
            "Light, Always use light appearance"
        )
        XCTAssertEqual(
            AppAppearanceMode.system.accessibilityLabel(isSelected: true),
            "System, selected, Match device appearance"
        )
    }

    func testThemeSettingsPaletteAccessibilityLabelsIncludeSelectionState() {
        XCTAssertEqual(
            AppThemePalette.oceanBlue.accessibilityLabel(isSelected: true),
            "Ocean Blue, selected, Calm and focused"
        )
        XCTAssertEqual(
            AppThemePalette.blossomPink.accessibilityLabel(isSelected: false),
            "Blossom Pink, Warm and friendly"
        )
        XCTAssertEqual(
            AppThemePalette.emeraldGreen.accessibilityLabel(isSelected: true),
            "Emerald Green, selected, Fresh and healthy"
        )
    }

    func testThemeSettingsSelectedStateUsesNonColorCues() {
        XCTAssertTrue(ThemeSettingsSelectionAccessibilityPolicy.includesCheckmarkForSelectedState)
        XCTAssertTrue(ThemeSettingsSelectionAccessibilityPolicy.includesSelectedTraitForSelectedState)
        XCTAssertTrue(ThemeSettingsSelectionAccessibilityPolicy.includesSelectedInAccessibilityLabel)
        XCTAssertTrue(ThemeSettingsSelectionAccessibilityPolicy.includesBorderForSelectedState)
    }

    // MARK: - System accessibility settings (documented policy)

    func testThemeSystemDocumentsUnsupportedAccessibilityAdaptations() {
        XCTAssertFalse(ThemeAccessibilityAdaptationPolicy.supportsIncreasedContrastPaletteVariants)
        XCTAssertFalse(ThemeAccessibilityAdaptationPolicy.supportsReduceTransparencyCompositing)
        XCTAssertNotNil(ThemeAccessibilityAdaptationPolicy.increasedContrastTODO)
        XCTAssertNotNil(ThemeAccessibilityAdaptationPolicy.reduceTransparencyTODO)
    }

    // MARK: - Helpers

    private func assertPairPasses(
        pair: String,
        minimum: CGFloat,
        colors: (FormaColorPalette, ColorScheme) -> (Color, Color),
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for themePalette in FormaPaletteCatalog.registeredThemePalettes {
            for colorScheme in FormaPaletteCatalog.registeredColorSchemes {
                let palette = FormaPaletteCatalog.palette(for: themePalette, colorScheme: colorScheme)
                let (foreground, background) = colors(palette, colorScheme)
                let ratio = FormaColorContrast.contrastRatio(foreground: foreground, background: background)
                XCTAssertGreaterThanOrEqual(
                    ratio,
                    minimum,
                    "\(pair) failed for \(themePalette.rawValue) \(colorScheme): \(ratio) < \(minimum)",
                    file: file,
                    line: line
                )
            }
        }
    }
}
