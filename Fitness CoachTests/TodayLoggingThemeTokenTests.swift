//
//  TodayLoggingThemeTokenTests.swift
//  Fitness CoachTests
//
//  Forma — Theme token wiring for Today meal/water logging surfaces.
//

import SwiftUI
import XCTest
@testable import Fitness_Coach

final class TodayLoggingThemeTokenTests: XCTestCase {

    private let todayLoggingSourcePrefixes = [
        "Fitness Coach/Features/Today/Components/TodayQuickActionsSection.swift",
        "Fitness Coach/Features/Today/Components/TodayWaterQuickLogSection.swift",
        "Fitness Coach/Features/Today/Components/TodayNextActionSection.swift",
        "Fitness Coach/Features/Today/TodayInteractionStyles.swift",
        "Fitness Coach/Features/Today/TodayLayout.swift",
        "Fitness Coach/DesignSystem/Components/FormaTransientBanner.swift",
        "Fitness Coach/DesignSystem/Components/FormaInlineEmptyState.swift"
    ]

    override func tearDown() async throws {
        await MainActor.run {
            ThemeTestSupport.resetThemeAccessToProductDefault()
        }
        try await super.tearDown()
    }

    func testNoHardcodedColorsInTodayLoggingSurfaces() {
        let violations = HardcodedColorGuard.scan(repositoryRoot: ThemeTestSupport.repositoryRoot())
        let loggingViolations = violations.filter { violation in
            todayLoggingSourcePrefixes.contains(violation.relativePath)
        }
        XCTAssertTrue(
            loggingViolations.isEmpty,
            loggingViolations.map(\.diagnosticMessage).joined(separator: "\n")
        )
    }

    func testProgressBarUsesSelectedPalette() async {
        await MainActor.run {
            for palette in [AppThemePalette.oceanBlue, .blossomPink, .emeraldGreen, .sunsetOrange] {
                FormaThemeAccess.update(
                    resolved: ThemeTestSupport.makeResolved(palette: palette, systemColorScheme: .dark)
                )
                let expected = FormaPaletteCatalog.palette(for: palette, colorScheme: .dark)
                ThemeTestSupport.assertSameColor(FormaTokens.Color.progress, expected.progress)
                ThemeTestSupport.assertSameColor(FormaTokens.Color.progressTrack, expected.progressTrack)
            }
        }
    }

    func testWaterQuickAddColorsFollowSelectedPalette() async {
        await MainActor.run {
            FormaThemeAccess.update(
                resolved: ThemeTestSupport.makeResolved(palette: .blossomPink, systemColorScheme: .dark)
            )
            let blossomPrimary = FormaTokens.Theme.primary
            let blossomSelectedBackground = TodayWaterQuickAddColors.background(isDisabled: false, isSelected: true)

            FormaThemeAccess.update(
                resolved: ThemeTestSupport.makeResolved(palette: .sunsetOrange, systemColorScheme: .dark)
            )
            let sunsetPrimary = FormaTokens.Theme.primary
            let sunsetSelectedBackground = TodayWaterQuickAddColors.background(isDisabled: false, isSelected: true)

            ThemeTestSupport.assertSameColor(blossomSelectedBackground, blossomPrimary)
            ThemeTestSupport.assertSameColor(sunsetSelectedBackground, sunsetPrimary)
            XCTAssertGreaterThan(ThemeTestSupport.colorDistance(blossomPrimary, sunsetPrimary), 0.08)
        }
    }

    func testDisabledWaterQuickAddUsesSemanticMutedTokens() async {
        await MainActor.run {
            ThemeTestSupport.resetThemeAccessToProductDefault()
            let palette = FormaPaletteCatalog.palette(for: .oceanBlue, colorScheme: .dark)

            ThemeTestSupport.assertSameColor(
                TodayWaterQuickAddColors.foreground(isDisabled: true, isSelected: false),
                palette.textTertiary
            )
            ThemeTestSupport.assertSameColor(
                TodayWaterQuickAddColors.background(isDisabled: true, isSelected: false),
                palette.surfaceSubtle
            )
        }
    }

    func testTransientBannerSuccessUsesPrimaryButtonBackground() async {
        await MainActor.run {
            for palette in [AppThemePalette.oceanBlue, .blossomPink, .emeraldGreen, .sunsetOrange] {
                FormaThemeAccess.update(
                    resolved: ThemeTestSupport.makeResolved(palette: palette, systemColorScheme: .dark)
                )
                let expected = ThemePaletteCatalog.palette(for: palette, colorScheme: .dark)
                ThemeTestSupport.assertSameColor(
                    FormaTokens.Theme.primaryButtonBackground,
                    expected.primaryButtonBackground
                )
                ThemeTestSupport.assertSameColor(
                    FormaTokens.Theme.textOnAccent,
                    expected.textOnAccent
                )
            }
        }
    }
}
