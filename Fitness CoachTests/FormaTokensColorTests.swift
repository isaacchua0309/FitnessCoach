//
//  FormaTokensColorTests.swift
//  Fitness CoachTests
//
//  Forma — FormaTokens.Color facade and ThemeColorProvider coverage.
//

import SwiftUI
import XCTest
@testable import Fitness_Coach

final class FormaTokensColorTests: XCTestCase {

    override func tearDown() async throws {
        await MainActor.run {
            FormaThemeAccess.resetToProductDefault()
        }
        try await super.tearDown()
    }

    // MARK: - Default baseline

    func testTokenFacadeReturnsDefaultDarkBaseline() async {
        await MainActor.run {
            FormaThemeAccess.resetToProductDefault()

            let expected = ThemeColorProvider.productDefault
            XCTAssertEqual(FormaThemeAccess.currentColors, expected)
            assertSameColor(FormaTokens.Color.canvas, expected.canvas)
            assertSameColor(FormaTokens.Color.accent, expected.accent)
            assertSameColor(FormaTokens.Color.surface, expected.surface)
            assertSameColor(FormaTokens.Color.borderSelected, expected.borderSelected)
        }
    }

    // MARK: - Palette changes

    func testTokenFacadeChangesAccentAcrossPalettes() async {
        await MainActor.run {
            let blossomResolved = makeResolved(palette: .blossomPink, colorScheme: .dark)
            FormaThemeAccess.update(resolved: blossomResolved)
            assertSameColor(
                FormaTokens.Color.accent,
                FormaPaletteCatalog.palette(for: .blossomPink, colorScheme: .dark).accent
            )

            let emeraldResolved = makeResolved(palette: .emeraldGreen, colorScheme: .dark)
            FormaThemeAccess.update(resolved: emeraldResolved)
            assertSameColor(
                FormaTokens.Color.accent,
                FormaPaletteCatalog.palette(for: .emeraldGreen, colorScheme: .dark).accent
            )

            XCTAssertGreaterThan(
                colorDistance(FormaTokens.Color.accent, blossomResolved.colors.accent),
                0
            )
        }
    }

    // MARK: - Feedback semantics

    func testSuccessWarningDestructiveTokensExistAndMatchProvider() async {
        await MainActor.run {
            FormaThemeAccess.resetToProductDefault()
            let expected = ThemeColorProvider.productDefault

            assertSameColor(FormaTokens.Color.success, expected.success)
            assertSameColor(FormaTokens.Color.warning, expected.warning)
            assertSameColor(FormaTokens.Color.destructive, expected.destructive)

            XCTAssertGreaterThan(FormaColorContrast.alpha(FormaTokens.Color.success), 0.5)
            XCTAssertGreaterThan(FormaColorContrast.alpha(FormaTokens.Color.warning), 0.5)
            XCTAssertGreaterThan(FormaColorContrast.alpha(FormaTokens.Color.destructive), 0.5)
        }
    }

    // MARK: - Brand exceptions

    func testGoogleButtonColorsAreApprovedBrandExceptions() async {
        await MainActor.run {
            FormaThemeAccess.resetToProductDefault()

            let approved = FormaBrandColorTokens.googleSignIn(
                colorScheme: .dark,
                borderBase: FormaColorPaletteCatalog.defaultDark.border
            )

            assertSameColor(FormaTokens.Color.googleButtonBackground, approved.background)
            assertSameColor(FormaTokens.Color.googleButtonForeground, approved.foreground)
            assertSameColor(FormaTokens.Color.googleButtonText, approved.foreground)
            assertSameColor(FormaTokens.Color.googleButtonBorder, approved.border)

            XCTAssertEqual(FormaBrandColorTokens.approvedTokenIDs.count, 5)
            XCTAssertTrue(FormaBrandColorTokens.approvedTokenIDs.contains("googleSignIn.shadow"))
            XCTAssertTrue(FormaBrandColorTokens.approvedTokenIDs.contains("googleSignIn.background"))
            XCTAssertTrue(FormaBrandColorTokens.approvedTokenIDs.contains("googleSignIn.foreground"))
            XCTAssertTrue(FormaBrandColorTokens.approvedTokenIDs.contains("googleSignIn.border"))

            // Accent follows theme; Google fill/label stay brand-fixed.
            let pinkResolved = makeResolved(palette: .blossomPink, colorScheme: .dark)
            FormaThemeAccess.update(resolved: pinkResolved)
            assertSameColor(FormaTokens.Color.googleButtonBackground, approved.background)
            assertSameColor(FormaTokens.Color.googleButtonForeground, approved.foreground)
            assertSameColor(
                FormaTokens.Color.accent,
                pinkResolved.colors.accent
            )
            XCTAssertGreaterThan(
                colorDistance(FormaTokens.Color.accent, FormaTokens.Color.googleButtonForeground),
                0.05
            )
        }
    }

    func testThemeColorProviderMatchesFormaTokensAfterRootUpdate() async {
        await MainActor.run {
            let resolved = makeResolved(palette: .emeraldGreen, colorScheme: .light)
            FormaThemeAccess.update(resolved: resolved)

            let providerColors = ThemeColorProvider.colors(from: resolved)
            XCTAssertEqual(FormaThemeAccess.currentColors, providerColors)
            assertSameColor(FormaTokens.Color.textPrimary, providerColors.textPrimary)
            assertSameColor(FormaTokens.Color.googleButtonBorder, providerColors.googleButtonBorder)
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
