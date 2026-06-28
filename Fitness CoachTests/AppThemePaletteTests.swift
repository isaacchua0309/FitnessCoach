//
//  AppThemePaletteTests.swift
//  Fitness CoachTests
//
//  Forma — AppThemePalette defaults, persistence, and display copy.
//

import XCTest
@testable import Fitness_Coach

final class AppThemePaletteTests: XCTestCase {

    func testLegacyDefaultIsDefaultForma() {
        XCTAssertEqual(AppThemePalette.legacyDefault, .default)
        XCTAssertEqual(AppThemePreferences.default.palette, .default)
    }

    func testLoadsCanonicalAndLegacyPersistedRawValues() {
        XCTAssertEqual(AppThemePalette(storedRawValue: "default"), .default)
        XCTAssertEqual(AppThemePalette(storedRawValue: "defaultForma"), .default)
        XCTAssertEqual(AppThemePalette(storedRawValue: "pink"), .pink)
        XCTAssertEqual(AppThemePalette(storedRawValue: "coolBlue"), .coolBlue)
    }

    func testFallsBackToDefaultForMissingOrUnknownRawValue() {
        XCTAssertEqual(AppThemePalette(storedRawValue: nil), .default)
        XCTAssertEqual(AppThemePalette(storedRawValue: "neon"), .default)
    }

    func testPersistenceRawValueUsesCanonicalKeys() {
        XCTAssertEqual(AppThemePalette.default.persistenceRawValue, "default")
        XCTAssertEqual(AppThemePalette.pink.persistenceRawValue, "pink")
        XCTAssertEqual(AppThemePalette.coolBlue.persistenceRawValue, "coolBlue")
    }

    func testDisplayNamesMatchFormaProductCopy() {
        XCTAssertEqual(AppThemePalette.default.displayName, "Default Forma")
        XCTAssertEqual(AppThemePalette.pink.displayName, "Pink")
        XCTAssertEqual(AppThemePalette.coolBlue.displayName, "Cool Blue")
    }

    func testDescriptionsMatchFormaProductCopy() {
        XCTAssertEqual(AppThemePalette.default.description, "Forma's signature palette.")
        XCTAssertEqual(AppThemePalette.pink.description, "Warm rose tones.")
        XCTAssertEqual(AppThemePalette.coolBlue.description, "Calm blue tones.")
    }

    func testAccessibilityLabelsIncludeSelectionState() {
        XCTAssertEqual(
            AppThemePalette.pink.accessibilityLabel(isSelected: true),
            "Pink, selected, Warm rose tones"
        )
        XCTAssertEqual(
            AppThemePalette.coolBlue.accessibilityLabel(isSelected: false),
            "Cool Blue, Calm blue tones"
        )
    }

    func testPreferencesRoundTripPreservesPalette() throws {
        let suiteName = "AppThemePaletteTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let original = AppThemePreferences(appearance: .dark, palette: .coolBlue)
        original.write(to: defaults)

        let loaded = AppThemePreferences(userDefaults: defaults)
        XCTAssertEqual(loaded.palette, .coolBlue)
        XCTAssertEqual(defaults.string(forKey: AppThemePreferences.PersistenceKey.palette), "coolBlue")
    }

    func testPreferencesReadLegacyPaletteKey() {
        let preferences = AppThemePreferences(
            appearanceRawValue: "dark",
            paletteRawValue: "defaultForma"
        )
        XCTAssertEqual(preferences.palette, .default)
    }
}
