//
//  ThemeSettingsViewTests.swift
//  Fitness CoachTests
//
//  Forma — Theme settings catalog, selection state, and store wiring.
//

import XCTest
@testable import Fitness_Coach

final class ThemeSettingsViewTests: XCTestCase {

    func testSettingsPreferencesIncludesThemeRow() {
        XCTAssertTrue(SettingsPreferencesCatalog.rowTitles.contains("Theme"))
        XCTAssertEqual(
            SettingsPreferencesCatalog.themeRowTitle,
            FormaProductCopy.Settings.Theme.navigationRowTitle
        )
    }

    func testExistingUsersDefaultToDarkOceanBluePalette() async {
        await MainActor.run {
            let store = ThemeStore(userDefaults: ThemeTestSupport.makeIsolatedDefaults(suiteNamePrefix: "ThemeSettingsViewTests"))
            XCTAssertEqual(store.appearance, .dark)
            XCTAssertEqual(store.palette, .oceanBlue)
            XCTAssertEqual(store.preferredColorScheme, .dark)
        }
    }

    func testChangingAppearanceUpdatesThemeStore() async {
        await MainActor.run {
            let defaults = ThemeTestSupport.makeIsolatedDefaults(suiteNamePrefix: "ThemeSettingsViewTests.appearance")
            let store = ThemeStore(userDefaults: defaults)

            store.setAppearance(.light)
            XCTAssertEqual(store.appearance, .light)
            XCTAssertEqual(
                defaults.string(forKey: AppThemePreferences.PersistenceKey.appearance),
                AppAppearanceMode.light.rawValue
            )

            store.setAppearance(.system)
            XCTAssertEqual(store.appearance, .system)
            XCTAssertNil(store.preferredColorScheme)
        }
    }

    func testChangingPaletteUpdatesThemeStore() async {
        await MainActor.run {
            let defaults = ThemeTestSupport.makeIsolatedDefaults(suiteNamePrefix: "ThemeSettingsViewTests.palette")
            let store = ThemeStore(userDefaults: defaults)

            store.setPalette(.blossomPink)
            XCTAssertEqual(store.palette, .blossomPink)
            XCTAssertEqual(
                defaults.string(forKey: AppThemePreferences.PersistenceKey.palette),
                AppThemePalette.blossomPink.rawValue
            )

            store.setPalette(.emeraldGreen)
            XCTAssertEqual(store.palette, .emeraldGreen)
        }
    }

    func testSelectedStateReflectsStoreSelection() async {
        await MainActor.run {
            let store = ThemeStore(userDefaults: ThemeTestSupport.makeIsolatedDefaults(suiteNamePrefix: "ThemeSettingsViewTests.selected"))
            store.setAppearance(.light)
            store.setPalette(.blossomPink)

            XCTAssertTrue(store.appearance == .light)
            XCTAssertFalse(store.appearance == .dark)
            XCTAssertTrue(store.palette == .blossomPink)
            XCTAssertFalse(store.palette == .oceanBlue)
        }
    }

    func testPalettePreviewSwatchesUseCatalogValues() {
        let palette = FormaPaletteCatalog.palette(for: .blossomPink, colorScheme: .dark)
        XCTAssertEqual(palette.previewSwatches.count, 3)
        XCTAssertEqual(palette.previewSwatches[0], palette.accent)
        XCTAssertEqual(palette.previewSwatches[1], palette.surfaceElevated)
        XCTAssertEqual(palette.previewSwatches[2], palette.canvas)
    }

    func testSelectedPaletteAccessibilityLabelIncludesSelectedTraitCopy() {
        let label = AppThemePalette.blossomPink.accessibilityLabel(isSelected: true)
        XCTAssertTrue(label.contains("selected"))
        XCTAssertFalse(label.contains("not selected"))
        XCTAssertTrue(label.contains("Blossom Pink"))
        XCTAssertTrue(label.contains("Warm and friendly"))
    }

    func testUnselectedPaletteAccessibilityLabelIncludesNotSelectedCopy() {
        let label = AppThemePalette.emeraldGreen.accessibilityLabel(isSelected: false)
        XCTAssertTrue(label.contains("not selected"))
        XCTAssertFalse(label.hasSuffix("selected"))
    }

    func testReloadAppliesShippingPolicyToPersistedAppearance() async {
        await MainActor.run {
            let defaults = ThemeTestSupport.makeIsolatedDefaults(suiteNamePrefix: "ThemeSettingsViewTests.reload")
            defaults.set(
                AppAppearanceMode.system.rawValue,
                forKey: AppThemePreferences.PersistenceKey.appearance
            )
            defaults.set(
                AppThemePalette.emeraldGreen.rawValue,
                forKey: AppThemePreferences.PersistenceKey.palette
            )

            let store = ThemeStore(userDefaults: defaults)
            XCTAssertEqual(store.appearance, .dark)
            XCTAssertEqual(store.palette, .emeraldGreen)
        }
    }

    func testThemeSelectionPolicyIncludesNonColorCues() {
        XCTAssertTrue(ThemeSettingsSelectionAccessibilityPolicy.includesCheckmarkForSelectedState)
        XCTAssertTrue(ThemeSettingsSelectionAccessibilityPolicy.includesSelectedTraitForSelectedState)
        XCTAssertTrue(ThemeSettingsSelectionAccessibilityPolicy.includesSelectedInAccessibilityLabel)
        XCTAssertTrue(ThemeSettingsSelectionAccessibilityPolicy.includesNotSelectedInAccessibilityLabel)
        XCTAssertTrue(ThemeSettingsSelectionAccessibilityPolicy.includesBorderForSelectedState)
        XCTAssertTrue(ThemeSettingsSelectionAccessibilityPolicy.meetsMinimumTouchTarget)
    }

    func testAppearanceMatrixCoversAllPaletteCombinations() {
        XCTAssertEqual(FormaThemeAppearanceMatrix.combinations.count, 8)
        XCTAssertEqual(FormaThemeAppearanceMatrix.palettes, AppThemePalette.allCases)
        XCTAssertEqual(FormaThemeAppearanceMatrix.appearances, [.light, .dark])
    }
}
