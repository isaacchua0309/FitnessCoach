//
//  ThemeSelectorTests.swift
//  Fitness CoachTests
//
//  Forma — Theme selector defaults, migration, persistence, catalog, and live preview.
//

import SwiftUI
import XCTest
@testable import Fitness_Coach

@MainActor
final class ThemeSelectorTests: XCTestCase {

    override func tearDown() async throws {
        ThemeTestSupport.resetThemeAccessToProductDefault()
        try await super.tearDown()
    }

    // MARK: - 1. Default

    func testAppDefaultsToOceanBlue() {
        let store = ThemeStore(userDefaults: makeIsolatedDefaults())
        XCTAssertEqual(AppThemePalette.legacyDefault, .oceanBlue)
        XCTAssertEqual(AppThemePreferences.default.palette, .oceanBlue)
        XCTAssertEqual(store.palette, .oceanBlue)
    }

    // MARK: - 2–5. Migration and fallback

    func testOldSavedDefaultMigratesToOceanBlue() {
        let defaults = makeIsolatedDefaults()
        defaults.set("default", forKey: AppThemePreferences.PersistenceKey.palette)

        let store = ThemeStore(userDefaults: defaults)
        XCTAssertEqual(store.palette, .oceanBlue)
        XCTAssertEqual(
            defaults.string(forKey: AppThemePreferences.PersistenceKey.palette),
            AppThemePalette.oceanBlue.rawValue
        )
    }

    func testOldSavedBlueMigratesToOceanBlue() {
        let defaults = makeIsolatedDefaults()
        defaults.set("blue", forKey: AppThemePreferences.PersistenceKey.palette)

        let store = ThemeStore(userDefaults: defaults)
        XCTAssertEqual(store.palette, .oceanBlue)
        XCTAssertEqual(
            defaults.string(forKey: AppThemePreferences.PersistenceKey.palette),
            AppThemePalette.oceanBlue.rawValue
        )
    }

    func testOldSavedPinkMigratesToBlossomPink() {
        let defaults = makeIsolatedDefaults()
        defaults.set("pink", forKey: AppThemePreferences.PersistenceKey.palette)

        let store = ThemeStore(userDefaults: defaults)
        XCTAssertEqual(store.palette, .blossomPink)
        XCTAssertEqual(
            defaults.string(forKey: AppThemePreferences.PersistenceKey.palette),
            AppThemePalette.blossomPink.rawValue
        )
    }

    func testUnknownSavedThemeFallsBackToOceanBlue() {
        let defaults = makeIsolatedDefaults()
        defaults.set("neon", forKey: AppThemePreferences.PersistenceKey.palette)

        let store = ThemeStore(userDefaults: defaults)
        XCTAssertEqual(store.palette, .oceanBlue)
        XCTAssertEqual(
            defaults.string(forKey: AppThemePreferences.PersistenceKey.palette),
            AppThemePalette.oceanBlue.rawValue
        )
    }

    // MARK: - 6–7. Selection and immediate update

    func testSelectingEmeraldGreenPersistsEmeraldGreen() {
        let defaults = makeIsolatedDefaults()
        let store = ThemeStore(userDefaults: defaults)

        store.setPalette(.emeraldGreen)

        XCTAssertEqual(store.palette, .emeraldGreen)
        XCTAssertEqual(
            defaults.string(forKey: AppThemePreferences.PersistenceKey.palette),
            AppThemePalette.emeraldGreen.rawValue
        )

        let reloaded = ThemeStore(userDefaults: defaults)
        XCTAssertEqual(reloaded.palette, .emeraldGreen)
    }

    func testSelectingSunsetOrangeUpdatesActiveThemeImmediately() {
        let store = ThemeStore(userDefaults: makeIsolatedDefaults())
        store.setPalette(.sunsetOrange)

        let state = FormaThemeRootState.make(store: store, systemColorScheme: .dark)
        FormaThemeAccess.update(resolved: state.resolved)

        XCTAssertEqual(FormaThemeAccess.currentThemePalette.id, .sunsetOrange)
        ThemeTestSupport.assertSameColor(
            FormaTokens.Theme.primary,
            ThemePaletteCatalog.palette(for: .sunsetOrange, colorScheme: .dark).primary
        )
        ThemeTestSupport.assertSameColor(
            FormaTokens.Color.progress,
            FormaPaletteCatalog.palette(for: .sunsetOrange, colorScheme: .dark).progress
        )
    }

    // MARK: - 8–9. Catalog integrity

    func testThemeListContainsExactlyFourThemes() {
        XCTAssertEqual(AppThemePalette.allCases.count, 4)
        XCTAssertEqual(ThemePaletteCatalog.registeredPalettes.count, 4)
        XCTAssertEqual(
            Set(AppThemePalette.allCases.map(\.rawValue)),
            Set(["oceanBlue", "blossomPink", "emeraldGreen", "sunsetOrange"])
        )
    }

    func testNoDuplicatePalettesBetweenThemes() {
        var primaries: [Color] = []
        var displayNames: Set<String> = []

        for paletteID in AppThemePalette.allCases {
            let theme = ThemePaletteCatalog.palette(for: paletteID, colorScheme: .dark)
            primaries.append(theme.primary)
            XCTAssertTrue(displayNames.insert(theme.displayName).inserted, theme.displayName)
        }

        for index in primaries.indices {
            for other in (index + 1)..<primaries.count {
                XCTAssertGreaterThan(
                    ThemeTestSupport.colorDistance(primaries[index], primaries[other]),
                    0.08,
                    "Theme primaries must be visually distinct"
                )
            }
        }
    }

    // MARK: - 10. Live preview tokens

    func testThemeLivePreviewUsesActiveThemeTokens() {
        let store = ThemeStore(userDefaults: makeIsolatedDefaults())
        store.setPalette(.blossomPink)

        applyActiveTheme(from: store, colorScheme: .dark)

        let catalog = FormaPaletteCatalog.palette(for: .blossomPink, colorScheme: .dark)
        let theme = ThemePaletteCatalog.palette(for: .blossomPink, colorScheme: .dark)

        ThemeTestSupport.assertSameColor(FormaTokens.Color.ctaBackground, catalog.ctaBackground)
        ThemeTestSupport.assertSameColor(FormaTokens.Color.ctaText, catalog.ctaText)
        ThemeTestSupport.assertSameColor(FormaTokens.Color.progress, catalog.progress)
        ThemeTestSupport.assertSameColor(FormaTokens.Color.progressTrack, catalog.progressTrack)
        ThemeTestSupport.assertSameColor(FormaTokens.Theme.primary, theme.primary)
        ThemeTestSupport.assertSameColor(FormaTokens.Theme.softBackground, theme.softBackground)
    }

    func testThemeLivePreviewTracksPaletteChangesWithoutRestart() {
        let store = ThemeStore(userDefaults: makeIsolatedDefaults())

        store.setPalette(.oceanBlue)
        applyActiveTheme(from: store, colorScheme: .dark)
        let oceanPrimary = FormaTokens.Theme.primary

        store.setPalette(.sunsetOrange)
        applyActiveTheme(from: store, colorScheme: .dark)
        let sunsetPrimary = FormaTokens.Theme.primary

        XCTAssertGreaterThan(ThemeTestSupport.colorDistance(oceanPrimary, sunsetPrimary), 0.08)
        ThemeTestSupport.assertSameColor(
            sunsetPrimary,
            ThemePaletteCatalog.palette(for: .sunsetOrange, colorScheme: .dark).primary
        )
    }

    // MARK: - Helpers

    private func makeIsolatedDefaults() -> UserDefaults {
        ThemeTestSupport.makeIsolatedDefaults(suiteNamePrefix: "ThemeSelectorTests")
    }

    private func applyActiveTheme(from store: ThemeStore, colorScheme: ColorScheme) {
        let state = FormaThemeRootState.make(store: store, systemColorScheme: colorScheme)
        FormaThemeAccess.update(resolved: state.resolved)
    }
}
