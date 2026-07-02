//
//  MainTabThemeSmokeTests.swift
//  Fitness CoachTests
//
//  Forma — Main tab token smoke tests and scoped theme guardrails.
//

import SwiftUI
import XCTest
@testable import Fitness_Coach

final class MainTabThemeSmokeTests: XCTestCase {

    private let mainAppSourcePrefixes = [
        "Fitness Coach/Features/Today/",
        "Fitness Coach/Features/Plan/",
        "Fitness Coach/Features/Journey/",
        "Fitness Coach/Features/Coach/",
        "Fitness Coach/Features/TrainingInsights/",
        "Fitness Coach/DesignSystem/Components/",
        "Fitness Coach/DesignSystem/Legacy/",
        "Fitness Coach/App/MainTabView.swift"
    ]

    override func tearDown() async throws {
        await MainActor.run {
            ThemeTestSupport.resetThemeAccessToProductDefault()
        }
        try await super.tearDown()
    }

    func testMainTabTokensResolveForEveryPalette() async {
        await MainActor.run {
            var accents: [Color] = []

            for palette in AppThemePalette.allCases {
                FormaThemeAccess.update(
                    resolved: ThemeTestSupport.makeResolved(palette: palette, systemColorScheme: .dark)
                )

                let accent = FormaTokens.Color.accent
                let canvas = FormaTokens.Color.canvas
                accents.append(accent)

                XCTAssertGreaterThan(ThemeTestSupport.colorDistance(accent, canvas), 0.05)
                ThemeTestSupport.assertSameColor(
                    FormaTokens.Color.progress,
                    FormaPaletteCatalog.palette(for: palette, colorScheme: .dark).progress
                )
                ThemeTestSupport.assertSameColor(
                    FormaTokens.Color.chartPrimary,
                    FormaPaletteCatalog.palette(for: palette, colorScheme: .dark).chartPrimary
                )
                ThemeTestSupport.assertSameColor(
                    CoachDesignTokens.Color.accent,
                    FormaPaletteCatalog.palette(for: palette, colorScheme: .dark).accent
                )
            }

            XCTAssertEqual(accents.count, AppThemePalette.allCases.count)
            for index in accents.indices {
                for other in (index + 1)..<accents.count {
                    XCTAssertGreaterThan(
                        ThemeTestSupport.colorDistance(accents[index], accents[other]),
                        0.08,
                        "Palette accents should be distinct"
                    )
                }
            }
        }
    }

    func testCoachDesignTokensTrackSelectedPalette() async {
        await MainActor.run {
            FormaThemeAccess.update(resolved: ThemeTestSupport.makeResolved(palette: .blossomPink, systemColorScheme: .dark))
            let pinkAccent = CoachDesignTokens.Color.accent

            FormaThemeAccess.update(resolved: ThemeTestSupport.makeResolved(palette: .emeraldGreen, systemColorScheme: .dark))
            XCTAssertGreaterThan(ThemeTestSupport.colorDistance(pinkAccent, CoachDesignTokens.Color.accent), 0.08)
        }
    }

    func testProgressAndChartTokensTrackSelectedPalette() async {
        await MainActor.run {
            FormaThemeAccess.update(resolved: ThemeTestSupport.makeResolved(palette: .blossomPink, systemColorScheme: .dark))
            let pinkProgress = FormaTokens.Color.progress
            let pinkChart = FormaTokens.Color.chartPrimary

            FormaThemeAccess.update(resolved: ThemeTestSupport.makeResolved(palette: .emeraldGreen, systemColorScheme: .dark))
            XCTAssertGreaterThan(ThemeTestSupport.colorDistance(pinkProgress, FormaTokens.Color.progress), 0.08)
            XCTAssertGreaterThan(ThemeTestSupport.colorDistance(pinkChart, FormaTokens.Color.chartPrimary), 0.08)
        }
    }

    func testSurfaceTokensTrackSelectedPalette() async {
        await MainActor.run {
            ThemeTestSupport.resetThemeAccessToProductDefault()
            let defaultCanvas = FormaTokens.Color.canvas

            FormaThemeAccess.update(resolved: ThemeTestSupport.makeResolved(palette: .blossomPink, systemColorScheme: .dark))
            XCTAssertGreaterThan(ThemeTestSupport.colorDistance(FormaTokens.Color.canvas, defaultCanvas), 0.02)
            ThemeTestSupport.assertSameColor(
                FormaTokens.Color.surfaceElevated,
                FormaPaletteCatalog.palette(for: .blossomPink, colorScheme: .dark).surfaceElevated
            )
        }
    }

    func testCTATokensTrackSelectedPalette() async {
        await MainActor.run {
            FormaThemeAccess.update(resolved: ThemeTestSupport.makeResolved(palette: .blossomPink, systemColorScheme: .dark))
            ThemeTestSupport.assertSameColor(
                FormaTokens.Color.ctaBackground,
                FormaPaletteCatalog.palette(for: .blossomPink, colorScheme: .dark).ctaBackground
            )
        }
    }

    func testNoHardcodedColorsInMainAppProductionFiles() {
        let violations = HardcodedColorGuard.scan(repositoryRoot: ThemeTestSupport.repositoryRoot())
            .filter { violation in
                mainAppSourcePrefixes.contains { violation.relativePath.hasPrefix($0) }
                    && !violation.relativePath.contains("/Preview/")
            }

        if violations.isEmpty { return }

        let report = violations.map(\.diagnosticMessage).joined(separator: "\n\n")
        XCTFail(
            """
            Found \(violations.count) hardcoded color literal(s) in main app production sources.

            \(report)
            """
        )
    }

    func testNoForcedDarkAppearanceInMainAppProductionFiles() {
        let violations = ForcedDarkAppearanceGuard.scan(repositoryRoot: ThemeTestSupport.repositoryRoot())
            .filter { violation in
                mainAppSourcePrefixes.contains { violation.relativePath.hasPrefix($0) }
            }

        if violations.isEmpty { return }

        let report = violations.map(\.diagnosticMessage).joined(separator: "\n\n")
        XCTFail(
            """
            Found \(violations.count) forced dark appearance call(s) in main app production sources.

            \(report)
            """
        )
    }
}
