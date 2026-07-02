//
//  PublicWelcomeThemeTests.swift
//  Fitness CoachTests
//
//  Forma — Public entry theme resolution and auth screen guardrails.
//

import SwiftUI
import XCTest
@testable import Fitness_Coach

final class PublicWelcomeThemeTests: XCTestCase {

    private let authSourcePrefixes = [
        "Fitness Coach/Features/Auth/"
    ]

    override func tearDown() async throws {
        await MainActor.run {
            FormaThemeAccess.resetToProductDefault()
        }
        try await super.tearDown()
    }

    // MARK: - Resolved theme

    func testPaletteUsesResolvedAppThemeNotHardcodedDark() async {
        await MainActor.run {
            let pink = makeResolved(palette: .blossomPink, colorScheme: .dark)
            FormaThemeAccess.update(resolved: pink)

            let palette = PublicWelcomeTheme.palette(from: pink)
            assertSameColor(palette.accent, pink.colors.accent)
            assertSameColor(palette.ctaBackground, pink.colors.ctaBackground)
            assertSameColor(palette.textPrimary, pink.colors.textPrimary)
        }
    }

    func testPaletteColorSchemeResolvesFromCurrentPreferences() async {
        await MainActor.run {
            let coolBlue = ThemeResolver.resolve(
                preferences: AppThemePreferences(appearance: .system, palette: .emeraldGreen),
                systemColorScheme: .light
            )
            FormaThemeAccess.update(resolved: coolBlue)

            let palette = PublicWelcomeTheme.palette(colorScheme: .light)
            assertSameColor(
                palette.accent,
                FormaPaletteCatalog.palette(for: .emeraldGreen, colorScheme: .light).accent
            )
            assertSameColor(
                palette.ctaBackground,
                FormaPaletteCatalog.palette(for: .emeraldGreen, colorScheme: .light).ctaBackground
            )
        }
    }

    func testPublicEntryCTAUsesSelectedPalette() async {
        await MainActor.run {
            FormaThemeAccess.update(resolved: makeResolved(palette: .blossomPink, colorScheme: .dark))
            let pinkCTA = PublicWelcomeTheme.palette(from: FormaThemeAccess.currentResolvedTheme).ctaBackground

            FormaThemeAccess.update(resolved: makeResolved(palette: .emeraldGreen, colorScheme: .dark))
            let coolBlueCTA = PublicWelcomeTheme.palette(from: FormaThemeAccess.currentResolvedTheme).ctaBackground

            XCTAssertGreaterThan(colorDistance(pinkCTA, coolBlueCTA), 0.08)
        }
    }

    func testWarningTokensRemainReadableAcrossPalettes() async {
        await MainActor.run {
            for themePalette in AppThemePalette.allCases {
                for scheme in [ColorScheme.dark, ColorScheme.light] {
                    let resolved = makeResolved(palette: themePalette, colorScheme: scheme)
                    let palette = PublicWelcomeTheme.palette(from: resolved)
                    XCTAssertGreaterThan(FormaColorContrast.alpha(palette.warning), 0.5)
                    XCTAssertGreaterThan(
                        colorDistance(palette.warning, palette.textPrimary),
                        0.05,
                        "Warning should contrast with primary text for \(themePalette.rawValue) \(scheme)"
                    )
                }
            }
        }
    }

    func testLogoutPreservesThemeForWelcomeReturn() async {
        await MainActor.run {
            let defaults = UserDefaults(suiteName: "PublicWelcomeThemeTests.\(UUID().uuidString)")!
            let store = ThemeStore(userDefaults: defaults)
            store.setAppearance(.dark)
            store.setPalette(.blossomPink)

            let syncStore = ProfileCloudSyncStore(userDefaults: defaults)
            syncStore.markSynced(uid: "user", updatedAt: ProfileTestFixtures.referenceDate)
            let sessionStore = PublicEntrySessionStore(userDefaults: defaults)

            AuthLogoutPolicy.clearTransientSessionMetadata(cloudSyncStore: syncStore)
            AuthLogoutPolicy.applyExplicitSignOut(sessionStore: sessionStore)

            let reloaded = ThemeStore(userDefaults: defaults)
            XCTAssertEqual(reloaded.palette, .blossomPink)
            XCTAssertEqual(reloaded.appearance, .dark)

            let welcomePalette = PublicWelcomeTheme.palette(
                from: reloaded.resolvedTheme(systemColorScheme: .dark)
            )
            assertSameColor(
                welcomePalette.accent,
                FormaPaletteCatalog.palette(for: .blossomPink, colorScheme: .dark).accent
            )
        }
    }

    // MARK: - Guardrails

    func testNoHardcodedColorsInAuthProductionFiles() {
        let root = repositoryRoot()
        let violations = HardcodedColorGuard.scan(repositoryRoot: root)
            .filter { violation in
                authSourcePrefixes.contains { violation.relativePath.hasPrefix($0) }
                    && !violation.relativePath.contains("/Components/PublicEntryPreviewScreens.swift")
            }

        if !violations.isEmpty {
            let report = violations.map(\.diagnosticMessage).joined(separator: "\n\n")
            XCTFail(
                """
                Found \(violations.count) hardcoded color literal(s) in auth production sources.

                \(report)
                """
            )
        }
    }

    func testNoForcedDarkAppearanceInAuthProductionFiles() {
        let root = repositoryRoot()
        let violations = ForcedDarkAppearanceGuard.scan(repositoryRoot: root)
            .filter { violation in
                authSourcePrefixes.contains { violation.relativePath.hasPrefix($0) }
            }

        if !violations.isEmpty {
            let report = violations.map(\.diagnosticMessage).joined(separator: "\n\n")
            XCTFail(
                """
                Found \(violations.count) forced dark appearance call(s) in auth production sources.

                \(report)
                """
            )
        }
    }

    func testGoogleSignInButtonUsesBrandTokens() async {
        await MainActor.run {
            FormaThemeAccess.update(resolved: makeResolved(palette: .blossomPink, colorScheme: .dark))
            let approved = FormaBrandColorTokens.googleSignIn(
                colorScheme: .dark,
                borderBase: FormaPaletteCatalog.defaultDark.border
            )
            assertSameColor(FormaTokens.Color.googleButtonBackground, approved.background)
            assertSameColor(FormaTokens.Color.googleButtonForeground, approved.foreground)
            XCTAssertGreaterThan(
                colorDistance(FormaTokens.Color.accent, FormaTokens.Color.googleButtonForeground),
                0.05
            )
        }
    }

    // MARK: - Helpers

    @MainActor
    private func makeResolved(
        palette: AppThemePalette,
        colorScheme: ColorScheme
    ) -> ResolvedAppTheme {
        ThemeResolver.resolve(
            preferences: AppThemePreferences(appearance: .dark, palette: palette),
            systemColorScheme: colorScheme
        )
    }

    private func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func assertSameColor(
        _ lhs: Color,
        _ rhs: Color,
        accuracy: CGFloat = 0.015,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let a = FormaColorContrast.rgbaComponents(for: lhs)
        let b = FormaColorContrast.rgbaComponents(for: rhs)
        XCTAssertEqual(a.red, b.red, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(a.green, b.green, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(a.blue, b.blue, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(a.alpha, b.alpha, accuracy: accuracy, file: file, line: line)
    }

    private func colorDistance(_ lhs: Color, _ rhs: Color) -> CGFloat {
        let a = FormaColorContrast.rgbaComponents(for: lhs)
        let b = FormaColorContrast.rgbaComponents(for: rhs)
        let deltaRed = a.red - b.red
        let deltaGreen = a.green - b.green
        let deltaBlue = a.blue - b.blue
        return sqrt(deltaRed * deltaRed + deltaGreen * deltaGreen + deltaBlue * deltaBlue)
    }
}
