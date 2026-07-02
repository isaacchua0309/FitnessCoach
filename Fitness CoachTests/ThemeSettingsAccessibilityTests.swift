//
//  ThemeSettingsAccessibilityTests.swift
//  Fitness CoachTests
//
//  Forma — Theme settings picker accessibility contract and contrast checks.
//

import SwiftUI
import XCTest
@testable import Fitness_Coach

final class ThemeSettingsAccessibilityTests: XCTestCase {

    // MARK: - VoiceOver labels

    func testPaletteAccessibilityLabelsUseTitleDescriptionSelectionFormat() {
        XCTAssertEqual(
            AppThemePalette.oceanBlue.accessibilityLabel(isSelected: true),
            "Ocean Blue, Calm and focused, selected"
        )
        XCTAssertEqual(
            AppThemePalette.emeraldGreen.accessibilityLabel(isSelected: false),
            "Emerald Green, Fresh and healthy, not selected"
        )
        XCTAssertEqual(
            AppThemePalette.blossomPink.accessibilityLabel(isSelected: true),
            "Blossom Pink, Warm and friendly, selected"
        )
        XCTAssertEqual(
            AppThemePalette.sunsetOrange.accessibilityLabel(isSelected: false),
            "Sunset Orange, Energetic and bold, not selected"
        )
    }

    func testAllPaletteAccessibilityLabelsIncludeExplicitSelectionState() {
        for palette in AppThemePalette.allCases {
            let selected = palette.accessibilityLabel(isSelected: true)
            let unselected = palette.accessibilityLabel(isSelected: false)

            XCTAssertTrue(selected.hasSuffix(", selected"), selected)
            XCTAssertTrue(unselected.hasSuffix(", not selected"), unselected)
            XCTAssertTrue(selected.contains(palette.displayName))
            XCTAssertTrue(selected.contains(palette.description))
            XCTAssertTrue(unselected.contains(palette.displayName))
            XCTAssertTrue(unselected.contains(palette.description))
        }
    }

    func testSelectionPolicyDocumentsNonColorCues() {
        XCTAssertTrue(ThemeSettingsSelectionAccessibilityPolicy.includesCheckmarkForSelectedState)
        XCTAssertTrue(ThemeSettingsSelectionAccessibilityPolicy.includesSelectedTraitForSelectedState)
        XCTAssertTrue(ThemeSettingsSelectionAccessibilityPolicy.includesSelectedInAccessibilityLabel)
        XCTAssertTrue(ThemeSettingsSelectionAccessibilityPolicy.includesNotSelectedInAccessibilityLabel)
        XCTAssertTrue(ThemeSettingsSelectionAccessibilityPolicy.includesBorderForSelectedState)
        XCTAssertTrue(ThemeSettingsSelectionAccessibilityPolicy.meetsMinimumTouchTarget)
    }

    func testPremiumPickerMeetsMinimumTouchTargetConstant() {
        XCTAssertGreaterThanOrEqual(
            ThemeSettingsPickerAccessibility.minimumCardTouchTarget,
            44
        )
        XCTAssertGreaterThan(
            ThemeSettingsPickerAccessibility.premiumPickerSelectedBorderLineWidth,
            ThemeSettingsPickerAccessibility.premiumPickerUnselectedBorderLineWidth
        )
    }

    // MARK: - Contrast and readability

    func testThemePickerContrastPairsMeetWCAGMinimums() {
        let failures = FormaPaletteContrastAudit.auditAllPalettes()
            .filter { $0.pair.contains("theme picker") || $0.pair.contains("textOnAccent on primary button") }

        if failures.isEmpty { return }

        let report = failures.map(\.description).joined(separator: "\n")
        XCTFail(
            """
            \(failures.count) theme picker contrast pair(s) below WCAG minimum:

            \(report)
            """
        )
    }

    func testThemedButtonTextContrastMeetsAAInDarkAndLight() {
        for palette in AppThemePalette.allCases {
            for scheme in FormaPaletteCatalog.registeredColorSchemes {
                let theme = ThemePaletteCatalog.palette(for: palette, colorScheme: scheme)
                let ratio = FormaColorContrast.contrastRatio(
                    foreground: theme.textOnAccent,
                    background: theme.primaryButtonBackground
                )
                XCTAssertGreaterThanOrEqual(
                    ratio,
                    4.5,
                    "textOnAccent on primary button failed for \(palette.rawValue) \(scheme): \(ratio)"
                )
            }
        }
    }

    func testDarkModeTextOnCanvasMeetsAAForAllPalettes() {
        for palette in AppThemePalette.allCases {
            let colors = FormaPaletteCatalog.palette(for: palette, colorScheme: .dark)
            let primaryRatio = FormaColorContrast.contrastRatio(
                foreground: colors.textPrimary,
                background: colors.canvas
            )
            let secondaryRatio = FormaColorContrast.contrastRatio(
                foreground: colors.textSecondary,
                background: colors.canvas
            )
            XCTAssertGreaterThanOrEqual(primaryRatio, 4.5, palette.rawValue)
            XCTAssertGreaterThanOrEqual(secondaryRatio, 3.0, palette.rawValue)
        }
    }

    // MARK: - Color-blind usability

    func testPaletteAccentHuesAreDistinctForColorVisionDeficiency() {
        var accents: [Color] = []
        for palette in AppThemePalette.allCases {
            let theme = ThemePaletteCatalog.palette(for: palette, colorScheme: .dark)
            accents.append(theme.primary)
        }

        for index in accents.indices {
            for other in (index + 1)..<accents.count {
                let distance = ThemeTestSupport.colorDistance(accents[index], accents[other])
                XCTAssertGreaterThanOrEqual(
                    distance,
                    0.08,
                    "Palette accents should be distinguishable without relying on selection color alone"
                )
            }
        }
    }
}
