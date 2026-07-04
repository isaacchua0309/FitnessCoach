//
//  PlanEditThemeComponentTests.swift
//  Fitness CoachTests
//
//  Forma — Edit Plan component theme wiring across palettes.
//

import SwiftUI
import XCTest
@testable import Fitness_Coach

final class PlanEditThemeComponentTests: XCTestCase {

    override func tearDown() async throws {
        await MainActor.run {
            FormaThemeAccess.resetToProductDefault()
        }
        try await super.tearDown()
    }

    func testSelectedCardChromeUsesThemeAccentAcrossPalettes() async {
        await MainActor.run {
            for palette in AppThemePalette.allCases {
                for scheme in [ColorScheme.light, ColorScheme.dark] {
                    let resolved = ThemeTestSupport.makeResolved(
                        palette: palette,
                        systemColorScheme: scheme
                    )
                    FormaThemeAccess.update(resolved: resolved)
                    let planColors = PlanThemeColorProvider.planColors(from: resolved)

                    ThemeTestSupport.assertSameColor(
                        PlanEditSelectionChrome.cardStrokeColor(isSelected: true),
                        planColors.planSelectedBorder
                    )
                    ThemeTestSupport.assertSameColor(
                        PlanEditSelectionChrome.cardBackground(isSelected: true),
                        planColors.planSelectedCardBackground
                    )
                    XCTAssertGreaterThan(
                        PlanEditSelectionChrome.cardStrokeWidth(isSelected: true),
                        PlanEditSelectionChrome.cardStrokeWidth(isSelected: false)
                    )
                }
            }
        }
    }

    func testUnselectedCardChromeUsesSubtleBorderAcrossPalettes() async {
        await MainActor.run {
            for palette in AppThemePalette.allCases {
                for scheme in [ColorScheme.light, ColorScheme.dark] {
                    let resolved = ThemeTestSupport.makeResolved(
                        palette: palette,
                        systemColorScheme: scheme
                    )
                    FormaThemeAccess.update(resolved: resolved)
                    let planColors = PlanThemeColorProvider.planColors(from: resolved)

                    ThemeTestSupport.assertSameColor(
                        PlanEditSelectionChrome.cardStrokeColor(isSelected: false),
                        planColors.planSubtleCardBorder
                    )
                    ThemeTestSupport.assertSameColor(
                        PlanEditSelectionChrome.cardBackground(isSelected: false),
                        planColors.planUnselectedCardBackground
                    )
                }
            }
        }
    }

    func testWarningTokensUseSemanticWarningNotPaletteAccent() async {
        await MainActor.run {
            for palette in AppThemePalette.allCases {
                for scheme in [ColorScheme.light, ColorScheme.dark] {
                    let resolved = ThemeTestSupport.makeResolved(
                        palette: palette,
                        systemColorScheme: scheme
                    )
                    FormaThemeAccess.update(resolved: resolved)
                    let planColors = PlanThemeColorProvider.planColors(from: resolved)

                    ThemeTestSupport.assertSameColor(
                        FormaPlanTokens.Color.planWarning,
                        planColors.planWarning
                    )
                    ThemeTestSupport.assertSameColor(
                        FormaPlanTokens.Color.planWarningSoft,
                        planColors.planWarningSoft
                    )
                    XCTAssertGreaterThan(
                        ThemeTestSupport.colorDistance(
                            FormaPlanTokens.Color.planWarning,
                            FormaPlanTokens.Color.planAccent
                        ),
                        0.05,
                        "Warning should stay distinct from accent for \(palette.rawValue)"
                    )
                    XCTAssertGreaterThan(
                        ThemeTestSupport.colorDistance(
                            FormaPlanTokens.Color.planWarning,
                            Color.blue
                        ),
                        0.05,
                        "Plan warning should not collapse to system blue for \(palette.rawValue)"
                    )
                }
            }
        }
    }

    func testFocusedInputChromeUsesThemeAccent() async {
        await MainActor.run {
            let resolved = ThemeTestSupport.makeResolved(
                palette: .blossomPink,
                systemColorScheme: .dark
            )
            FormaThemeAccess.update(resolved: resolved)
            let planColors = PlanThemeColorProvider.planColors(from: resolved)

            ThemeTestSupport.assertSameColor(
                PlanEditSelectionChrome.inputStrokeColor(isFocused: true, isInvalid: false),
                planColors.planAccent
            )
            ThemeTestSupport.assertSameColor(
                PlanEditSelectionChrome.inputStrokeColor(isFocused: false, isInvalid: true),
                planColors.planDanger
            )
        }
    }

    func testPlanAccentTracksActivePalette() async {
        await MainActor.run {
            let ocean = ThemeTestSupport.makeResolved(palette: .oceanBlue, systemColorScheme: .dark)
            let blossom = ThemeTestSupport.makeResolved(palette: .blossomPink, systemColorScheme: .dark)

            FormaThemeAccess.update(resolved: ocean)
            let oceanAccent = FormaPlanTokens.Color.planAccent

            FormaThemeAccess.update(resolved: blossom)
            let blossomAccent = FormaPlanTokens.Color.planAccent

            XCTAssertGreaterThan(
                ThemeTestSupport.colorDistance(oceanAccent, blossomAccent),
                0.05
            )
        }
    }
}
