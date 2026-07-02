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
            let palette = FormaPaletteCatalog.palette(for: .oceanBlue, colorScheme: .dark)

            ThemeTestSupport.assertSameColor(OnboardingTheme.background, palette.canvas)
            ThemeTestSupport.assertSameColor(OnboardingTheme.primary, palette.accent)
            ThemeTestSupport.assertSameColor(OnboardingTheme.progress, palette.progress)
            ThemeTestSupport.assertSameColor(OnboardingTheme.chartPrimary, palette.chartPrimary)
            ThemeTestSupport.assertSameColor(OnboardingTheme.ctaBackground, palette.ctaBackground)
        }
    }

    func testOnboardingCTAUsesSelectedPalette() async {
        await MainActor.run {
            FormaThemeAccess.update(resolved: ThemeTestSupport.makeResolved(palette: .blossomPink, systemColorScheme: .dark))
            let blossomCTA = OnboardingTheme.ctaBackground

            FormaThemeAccess.update(resolved: ThemeTestSupport.makeResolved(palette: .emeraldGreen, systemColorScheme: .dark))
            let emeraldCTA = OnboardingTheme.ctaBackground

            ThemeTestSupport.assertSameColor(
                blossomCTA,
                FormaPaletteCatalog.palette(for: .blossomPink, colorScheme: .dark).ctaBackground
            )
            ThemeTestSupport.assertSameColor(
                emeraldCTA,
                FormaPaletteCatalog.palette(for: .emeraldGreen, colorScheme: .dark).ctaBackground
            )
            XCTAssertGreaterThan(ThemeTestSupport.colorDistance(blossomCTA, emeraldCTA), 0.08)
        }
    }

    func testOnboardingProgressUsesSelectedPalette() async {
        await MainActor.run {
            FormaThemeAccess.update(resolved: ThemeTestSupport.makeResolved(palette: .blossomPink, systemColorScheme: .dark))
            let blossomProgress = OnboardingTheme.progress
            let blossomTrack = OnboardingTheme.progressTrack

            FormaThemeAccess.update(resolved: ThemeTestSupport.makeResolved(palette: .emeraldGreen, systemColorScheme: .dark))

            ThemeTestSupport.assertSameColor(
                blossomProgress,
                FormaPaletteCatalog.palette(for: .blossomPink, colorScheme: .dark).progress
            )
            ThemeTestSupport.assertSameColor(
                OnboardingTheme.progress,
                FormaPaletteCatalog.palette(for: .emeraldGreen, colorScheme: .dark).progress
            )
            XCTAssertGreaterThan(
                ThemeTestSupport.colorDistance(blossomProgress, OnboardingTheme.progress),
                0.08
            )
            XCTAssertGreaterThan(ThemeTestSupport.colorDistance(blossomTrack, OnboardingTheme.progressTrack), 0)
        }
    }

    func testOnboardingChartTokensUseSelectedPalette() async {
        await MainActor.run {
            FormaThemeAccess.update(resolved: ThemeTestSupport.makeResolved(palette: .blossomPink, systemColorScheme: .dark))

            ThemeTestSupport.assertSameColor(
                OnboardingTheme.chartPrimary,
                FormaPaletteCatalog.palette(for: .blossomPink, colorScheme: .dark).chartPrimary
            )
            ThemeTestSupport.assertSameColor(
                OnboardingTheme.chartSecondary,
                FormaPaletteCatalog.palette(for: .blossomPink, colorScheme: .dark).chartSecondary
            )

            FormaThemeAccess.update(resolved: ThemeTestSupport.makeResolved(palette: .emeraldGreen, systemColorScheme: .dark))
            XCTAssertGreaterThan(
                ThemeTestSupport.colorDistance(
                    OnboardingTheme.chartPrimary,
                    FormaPaletteCatalog.palette(for: .blossomPink, colorScheme: .dark).chartPrimary
                ),
                0.08
            )
        }
    }

    func testOnboardingThemeRecomputesWhenPaletteChanges() async {
        await MainActor.run {
            ThemeTestSupport.resetThemeAccessToProductDefault()
            let defaultPrimary = OnboardingTheme.primary

            FormaThemeAccess.update(resolved: ThemeTestSupport.makeResolved(palette: .blossomPink, systemColorScheme: .dark))
            XCTAssertGreaterThan(ThemeTestSupport.colorDistance(OnboardingTheme.primary, defaultPrimary), 0.08)

            ThemeTestSupport.resetThemeAccessToProductDefault()
            ThemeTestSupport.assertSameColor(OnboardingTheme.primary, defaultPrimary)
        }
    }

    func testNoHardcodedColorsRemainInOnboardingProductionFiles() {
        let violations = HardcodedColorGuard.scan(repositoryRoot: ThemeTestSupport.repositoryRoot)
        let onboardingViolations = violations.filter { violation in
            onboardingSourcePrefixes.contains { violation.relativePath.hasPrefix($0) }
        }
        XCTAssertTrue(
            onboardingViolations.isEmpty,
            onboardingViolations.map(\.diagnosticMessage).joined(separator: "\n")
        )
    }
}
