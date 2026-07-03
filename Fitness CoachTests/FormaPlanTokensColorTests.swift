//
//  FormaPlanTokensColorTests.swift
//  Fitness CoachTests
//
//  Forma — Edit / Adjust Plan semantic token coverage.
//

import SwiftUI
import XCTest
@testable import Fitness_Coach

final class FormaPlanTokensColorTests: XCTestCase {

    override func tearDown() async throws {
        await MainActor.run {
            FormaThemeAccess.resetToProductDefault()
        }
        try await super.tearDown()
    }

    func testPlanTokenFacadeReturnsProductDefaultBaseline() async {
        await MainActor.run {
            FormaThemeAccess.resetToProductDefault()

            let expected = PlanThemeColorProvider.productDefault
            XCTAssertEqual(FormaThemeAccess.currentPlanColors, expected)
            assertSameColor(FormaPlanTokens.Color.planBackground, expected.planBackground)
            assertSameColor(FormaPlanTokens.Color.planAccent, expected.planAccent)
            assertSameColor(FormaPlanTokens.Color.planWarning, expected.planWarning)
            assertSameColor(FormaPlanTokens.Color.planWarningSoft, expected.planWarningSoft)
        }
    }

    func testPlanAccentFollowsUserPalette() async {
        await MainActor.run {
            let blossom = makeResolved(palette: .blossomPink, colorScheme: .dark)
            FormaThemeAccess.update(resolved: blossom)

            assertSameColor(
                FormaPlanTokens.Color.planAccent,
                blossom.themePalette.primary
            )
            assertSameColor(
                FormaPlanTokens.Color.planProgressFill,
                blossom.colors.progress
            )

            let emerald = makeResolved(palette: .emeraldGreen, colorScheme: .light)
            FormaThemeAccess.update(resolved: emerald)
            assertSameColor(
                FormaPlanTokens.Color.planAccent,
                emerald.themePalette.primary
            )
            XCTAssertGreaterThan(
                colorDistance(FormaPlanTokens.Color.planAccent, blossom.themePalette.primary),
                0.05
            )
        }
    }

    func testPlanWarningTokensUseFeedbackSemanticsNotPaletteAccent() async {
        await MainActor.run {
            let pink = makeResolved(palette: .blossomPink, colorScheme: .dark)
            FormaThemeAccess.update(resolved: pink)

            assertSameColor(FormaPlanTokens.Color.planWarning, pink.colors.warning)
            assertSameColor(FormaPlanTokens.Color.planSuccess, pink.colors.success)
            assertSameColor(FormaPlanTokens.Color.planDanger, pink.colors.destructive)
            XCTAssertGreaterThan(
                colorDistance(FormaPlanTokens.Color.planWarning, FormaPlanTokens.Color.planAccent),
                0.05
            )
        }
    }

    func testPlanThemeColorProviderMergesFallbackSafely() async {
        let baseline = PlanThemeColorProvider.productDefault
        let partial = FormaPlanColors(
            background: baseline.background,
            surface: baseline.surface,
            elevatedSurface: baseline.elevatedSurface,
            primaryText: baseline.primaryText,
            secondaryText: baseline.secondaryText,
            mutedText: baseline.mutedText,
            accent: .pink,
            accentSoft: baseline.accentSoft,
            success: baseline.success,
            warning: baseline.warning,
            warningSoft: baseline.warningSoft,
            danger: baseline.danger,
            divider: baseline.divider,
            inputBackground: baseline.inputBackground,
            cardBorder: baseline.cardBorder,
            progressTrack: baseline.progressTrack,
            progressFill: baseline.progressFill,
            selectedCardBackground: baseline.selectedCardBackground,
            unselectedCardBackground: baseline.unselectedCardBackground
        )

        let merged = PlanThemeColorProvider.merging(baseline: baseline, override: partial)
        assertSameColor(merged.planAccent, .pink)
        assertSameColor(merged.planBackground, baseline.planBackground)
    }

    func testAllRegisteredPalettesProduceCompletePlanColors() async {
        await MainActor.run {
            for palette in AppThemePalette.allCases {
                for scheme in [ColorScheme.light, ColorScheme.dark] {
                    let resolved = makeResolved(palette: palette, colorScheme: scheme)
                    let planColors = PlanThemeColorProvider.planColors(from: resolved)

                    XCTAssertGreaterThan(FormaColorContrast.alpha(planColors.planBackground), 0.5)
                    XCTAssertGreaterThan(FormaColorContrast.alpha(planColors.planPrimaryText), 0.5)
                    XCTAssertGreaterThan(FormaColorContrast.alpha(planColors.planAccent), 0.5)
                    XCTAssertGreaterThan(FormaColorContrast.alpha(planColors.planWarning), 0.5)
                    XCTAssertGreaterThan(FormaColorContrast.alpha(planColors.planWarningSoft), 0.05)
                    XCTAssertGreaterThan(FormaColorContrast.alpha(planColors.planProgressFill), 0.5)
                }
            }
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
