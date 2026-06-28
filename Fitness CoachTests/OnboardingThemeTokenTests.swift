//
//  OnboardingThemeTokenTests.swift
//  Fitness CoachTests
//
//  Forma — Onboarding theme token resolution against active palette.
//

import SwiftUI
import XCTest
@testable import Fitness_Coach

final class OnboardingThemeTokenTests: XCTestCase {

    private let onboardingSourcePrefixes = [
        "Fitness Coach/Features/Onboarding/",
        "Fitness Coach/DesignSystem/Onboarding/"
    ]

    override func tearDown() async throws {
        await MainActor.run {
            ThemeTestSupport.resetThemeAccessToProductDefault()
        }
        try await super.tearDown()
    }

    func testDefaultOnboardingThemeMatchesProductDefaultPalette() async {
        await MainActor.run {
            ThemeTestSupport.resetThemeAccessToProductDefault()
            let palette = FormaPaletteCatalog.palette(for: .default, colorScheme: .dark)

            ThemeTestSupport.assertSameColor(OnboardingTheme.background, palette.canvas)
            ThemeTestSupport.assertSameColor(OnboardingTheme.accent, palette.accent)
            ThemeTestSupport.assertSameColor(OnboardingTheme.progress, palette.progress)
            ThemeTestSupport.assertSameColor(OnboardingTheme.chartPrimary, palette.chartPrimary)
            ThemeTestSupport.assertSameColor(OnboardingTheme.ctaBackground, palette.ctaBackground)
        }
    }

    func testOnboardingCTAUsesSelectedPalette() async {
        await MainActor.run {
            FormaThemeAccess.update(resolved: ThemeTestSupport.makeResolved(palette: .pink, systemColorScheme: .dark))
            let pinkCTA = OnboardingTheme.ctaBackground

            FormaThemeAccess.update(resolved: ThemeTestSupport.makeResolved(palette: .coolBlue, systemColorScheme: .dark))
            let coolBlueCTA = OnboardingTheme.ctaBackground

            ThemeTestSupport.assertSameColor(
                pinkCTA,
                FormaPaletteCatalog.palette(for: .pink, colorScheme: .dark).ctaBackground
            )
            ThemeTestSupport.assertSameColor(
                coolBlueCTA,
                FormaPaletteCatalog.palette(for: .coolBlue, colorScheme: .dark).ctaBackground
            )
            XCTAssertGreaterThan(ThemeTestSupport.colorDistance(pinkCTA, coolBlueCTA), 0.08)
        }
    }

    func testOnboardingProgressUsesSelectedPalette() async {
        await MainActor.run {
            FormaThemeAccess.update(resolved: ThemeTestSupport.makeResolved(palette: .pink, systemColorScheme: .dark))
            let pinkProgress = OnboardingTheme.progress
            let pinkTrack = OnboardingTheme.progressTrack

            FormaThemeAccess.update(resolved: ThemeTestSupport.makeResolved(palette: .coolBlue, systemColorScheme: .dark))

            ThemeTestSupport.assertSameColor(
                pinkProgress,
                FormaPaletteCatalog.palette(for: .pink, colorScheme: .dark).progress
            )
            ThemeTestSupport.assertSameColor(
                OnboardingTheme.progress,
                FormaPaletteCatalog.palette(for: .coolBlue, colorScheme: .dark).progress
            )
            XCTAssertGreaterThan(
                ThemeTestSupport.colorDistance(pinkProgress, OnboardingTheme.progress),
                0.08
            )
            XCTAssertGreaterThan(ThemeTestSupport.colorDistance(pinkTrack, OnboardingTheme.progressTrack), 0)
        }
    }

    func testOnboardingChartTokensUseSelectedPalette() async {
        await MainActor.run {
            FormaThemeAccess.update(resolved: ThemeTestSupport.makeResolved(palette: .pink, systemColorScheme: .dark))

            ThemeTestSupport.assertSameColor(
                OnboardingTheme.chartPrimary,
                FormaPaletteCatalog.palette(for: .pink, colorScheme: .dark).chartPrimary
            )
            ThemeTestSupport.assertSameColor(
                OnboardingTheme.chartSecondary,
                FormaPaletteCatalog.palette(for: .pink, colorScheme: .dark).chartSecondary
            )

            FormaThemeAccess.update(resolved: ThemeTestSupport.makeResolved(palette: .coolBlue, systemColorScheme: .dark))
            XCTAssertGreaterThan(
                ThemeTestSupport.colorDistance(
                    OnboardingTheme.chartPrimary,
                    FormaPaletteCatalog.palette(for: .pink, colorScheme: .dark).chartPrimary
                ),
                0.08
            )
        }
    }

    func testOnboardingThemeRecomputesWhenPaletteChanges() async {
        await MainActor.run {
            ThemeTestSupport.resetThemeAccessToProductDefault()
            let defaultAccent = OnboardingTheme.accent

            FormaThemeAccess.update(resolved: ThemeTestSupport.makeResolved(palette: .pink, systemColorScheme: .dark))
            XCTAssertGreaterThan(ThemeTestSupport.colorDistance(OnboardingTheme.accent, defaultAccent), 0.08)

            ThemeTestSupport.resetThemeAccessToProductDefault()
            ThemeTestSupport.assertSameColor(OnboardingTheme.accent, defaultAccent)
        }
    }

    func testNoHardcodedColorsRemainInOnboardingProductionFiles() {
        let violations = HardcodedColorGuard.scan(repositoryRoot: ThemeTestSupport.repositoryRoot())
            .filter { violation in
                onboardingSourcePrefixes.contains { violation.relativePath.hasPrefix($0) }
            }

        if violations.isEmpty { return }

        let report = violations.map(\.diagnosticMessage).joined(separator: "\n\n")
        XCTFail(
            """
            Found \(violations.count) hardcoded color literal(s) in onboarding production sources.

            \(report)
            """
        )
    }

    func testNoForcedDarkAppearanceInOnboardingProductionFiles() {
        let violations = ForcedDarkAppearanceGuard.scan(repositoryRoot: ThemeTestSupport.repositoryRoot())
            .filter { violation in
                onboardingSourcePrefixes.contains { violation.relativePath.hasPrefix($0) }
            }

        if violations.isEmpty { return }

        let report = violations.map(\.diagnosticMessage).joined(separator: "\n\n")
        XCTFail(
            """
            Found \(violations.count) forced dark appearance call(s) in onboarding production sources.

            \(report)
            """
        )
    }
}
