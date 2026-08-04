//
//  ThemeTokensProviderTests.swift
//  Fitness CoachTests
//
//  Forma — Semantic ThemeTokens mapping and environment parity.
//

import SwiftUI
import XCTest
@testable import Fitness_Coach

final class ThemeTokensProviderTests: XCTestCase {

    func testTokensMapResolvedThemeRoles() async {
        await MainActor.run {
            let resolved = ThemeTestSupport.makeResolved(palette: .sunsetOrange, systemColorScheme: .dark)
            let theme = ThemeTokensProvider.tokens(from: resolved)

            ThemeTestSupport.assertSameColor(theme.appBackground, resolved.colors.canvas)
            ThemeTestSupport.assertSameColor(theme.cardBackground, resolved.colors.surface)
            ThemeTestSupport.assertSameColor(theme.elevatedCardBackground, resolved.colors.surfaceElevated)
            ThemeTestSupport.assertSameColor(theme.primaryText, resolved.colors.textPrimary)
            ThemeTestSupport.assertSameColor(theme.secondaryText, resolved.colors.textSecondary)
            ThemeTestSupport.assertSameColor(theme.tertiaryText, resolved.colors.textTertiary)
            ThemeTestSupport.assertSameColor(theme.accent, resolved.themePalette.primary)
            ThemeTestSupport.assertSameColor(theme.accentSoftBackground, resolved.themePalette.softBackground)
            ThemeTestSupport.assertSameColor(theme.buttonBackground, resolved.themePalette.primaryButtonBackground)
            ThemeTestSupport.assertSameColor(theme.buttonText, resolved.themePalette.textOnAccent)
            ThemeTestSupport.assertSameColor(theme.progressTrack, resolved.colors.progressTrack)
            ThemeTestSupport.assertSameColor(theme.progressFill, resolved.colors.progress)
            ThemeTestSupport.assertSameColor(theme.destructive, resolved.colors.destructive)
            ThemeTestSupport.assertSameColor(theme.warning, resolved.colors.warning)
            ThemeTestSupport.assertSameColor(theme.success, resolved.colors.success)
            ThemeTestSupport.assertSameColor(theme.tabBarBackground, resolved.colors.canvas)
            ThemeTestSupport.assertSameColor(theme.tabBarSelectedBackground, resolved.colors.selectedBackground)
            ThemeTestSupport.assertSameColor(theme.tabBarSelectedIcon, resolved.themePalette.primary)
            ThemeTestSupport.assertSameColor(theme.tabBarUnselectedIcon, resolved.colors.textTertiary)
            ThemeTestSupport.assertSameColor(theme.inputBackground, resolved.colors.surfaceElevated)
            ThemeTestSupport.assertSameColor(theme.inputBorder, resolved.colors.border)
        }
    }

    @MainActor
    func testSettingResolvedThemeSyncsThemeEnvironment() {
        var environment = EnvironmentValues()
        let resolved = ThemeTestSupport.makeResolved(palette: .blossomPink, systemColorScheme: .dark)
        environment.formaResolvedTheme = resolved

        XCTAssertEqual(environment.theme, ThemeTokensProvider.tokens(from: resolved))
    }

    func testPriorityHealthCardsAvoidPalettePrimaryReads() throws {
        let root = ThemeTestSupport.repositoryRoot()
        let paths = [
            "Fitness Coach/Features/Today/Components/HealthIntelligence/TodayRecoveryCard.swift",
            "Fitness Coach/Features/Today/Components/HealthIntelligence/TodayAdaptiveNutritionCard.swift",
            "Fitness Coach/Features/Today/Components/TodayActivitySection.swift",
            "Fitness Coach/Features/Today/Components/HealthIntelligence/TodayHealthWorkoutCard.swift",
            "Fitness Coach/Features/Today/Components/HealthIntelligence/TodayHealthIntelligenceSection.swift",
            "Fitness Coach/Features/Settings/UI/AppleHealthIntegrationView.swift",
            "Fitness Coach/Features/Settings/UI/AppleHealthRemoteSyncSettingsView.swift"
        ]

        for relativePath in paths {
            let source = try String(
                contentsOf: root.appendingPathComponent(relativePath),
                encoding: .utf8
            )
            let productionSource = source.components(separatedBy: "#Preview").first ?? source
            XCTAssertFalse(
                productionSource.contains("palette.primary"),
                "\(relativePath) must use semantic theme tokens instead of palette.primary."
            )
            XCTAssertFalse(
                productionSource.contains("FormaTokens.Color."),
                "\(relativePath) must use @Environment(\\.theme) instead of static FormaTokens.Color reads."
            )
        }
    }
}
