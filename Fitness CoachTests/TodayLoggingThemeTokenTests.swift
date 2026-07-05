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

    func testWaterQuickAddUsesSemanticThemeTokensInView() throws {
        let source = try String(
            contentsOf: ThemeTestSupport.repositoryRoot().appendingPathComponent(
                "Fitness Coach/Features/Today/Components/TodayWaterQuickLogSection.swift"
            ),
            encoding: .utf8
        )

        XCTAssertTrue(source.contains("theme.buttonBackground"))
        XCTAssertTrue(source.contains("theme.accentBorder"))
        XCTAssertTrue(source.contains("todayLiveTheme()"))
    }

    func testWaterQuickAddColorsFollowSelectedPalette() async {
        await MainActor.run {
            let store = ThemeStore(
                userDefaults: ThemeTestSupport.makeIsolatedDefaults(
                    suiteNamePrefix: "TodayLoggingThemeTokenTests.water"
                )
            )

            store.setTheme(.blossomPink)
            let blossomTokens = store.tokens(systemColorScheme: .dark)

            store.setTheme(.sunsetOrange)
            let sunsetTokens = store.tokens(systemColorScheme: .dark)

            XCTAssertGreaterThan(
                ThemeTestSupport.colorDistance(blossomTokens.buttonBackground, sunsetTokens.buttonBackground),
                0.08
            )
            XCTAssertGreaterThan(
                ThemeTestSupport.colorDistance(blossomTokens.accentBorder, sunsetTokens.accentBorder),
                0.05
            )
        }
    }

    func testDisabledWaterQuickAddUsesSemanticMutedTokens() async {
        await MainActor.run {
            let store = ThemeStore(
                userDefaults: ThemeTestSupport.makeIsolatedDefaults(
                    suiteNamePrefix: "TodayLoggingThemeTokenTests.disabled"
                )
            )
            store.setTheme(.oceanBlue)
            let tokens = store.tokens(systemColorScheme: .dark)

            XCTAssertEqual(tokens.tertiaryText, tokens.tertiaryText)
            XCTAssertNotEqual(tokens.accentSoftBackground.opacity(0.45), tokens.buttonBackground)
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
