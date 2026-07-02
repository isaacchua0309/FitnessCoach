//
//  AppThemePaletteTests.swift
//  Fitness CoachTests
//
//  Forma — AppThemePalette defaults, persistence, and display copy.
//

import XCTest
@testable import Fitness_Coach

final class AppThemePaletteTests: XCTestCase {

    func testLegacyDefaultIsOceanBlue() {
        XCTAssertEqual(AppThemePalette.legacyDefault, .oceanBlue)
        XCTAssertEqual(AppThemePreferences.default.palette, .oceanBlue)
    }

    func testLoadsCanonicalPersistedRawValues() {
        XCTAssertEqual(AppThemePalette(storedRawValue: "oceanBlue"), .oceanBlue)
        XCTAssertEqual(AppThemePalette(storedRawValue: "blossomPink"), .blossomPink)
        XCTAssertEqual(AppThemePalette(storedRawValue: "emeraldGreen"), .emeraldGreen)
        XCTAssertEqual(AppThemePalette(storedRawValue: "sunsetOrange"), .sunsetOrange)
    }

    func testMigratesLegacyPersistedRawValues() {
        XCTAssertEqual(AppThemePalette(storedRawValue: "default"), .oceanBlue)
        XCTAssertEqual(AppThemePalette(storedRawValue: "defaultForma"), .oceanBlue)
        XCTAssertEqual(AppThemePalette(storedRawValue: "blue"), .oceanBlue)
        XCTAssertEqual(AppThemePalette(storedRawValue: "coolBlue"), .oceanBlue)
        XCTAssertEqual(AppThemePalette(storedRawValue: "pink"), .blossomPink)
    }

    func testFallsBackToOceanBlueForMissingOrUnknownRawValue() {
        XCTAssertEqual(AppThemePalette(storedRawValue: nil), .oceanBlue)
        XCTAssertEqual(AppThemePalette(storedRawValue: "neon"), .oceanBlue)
    }

    func testPersistenceRawValueUsesCanonicalKeys() {
        XCTAssertEqual(AppThemePalette.oceanBlue.persistenceRawValue, "oceanBlue")
        XCTAssertEqual(AppThemePalette.blossomPink.persistenceRawValue, "blossomPink")
        XCTAssertEqual(AppThemePalette.emeraldGreen.persistenceRawValue, "emeraldGreen")
        XCTAssertEqual(AppThemePalette.sunsetOrange.persistenceRawValue, "sunsetOrange")
    }

    func testShouldMigratePersistedRawValueForLegacyKeys() {
        XCTAssertTrue(AppThemePalette.shouldMigratePersistedRawValue("default"))
        XCTAssertTrue(AppThemePalette.shouldMigratePersistedRawValue("defaultForma"))
        XCTAssertTrue(AppThemePalette.shouldMigratePersistedRawValue("blue"))
        XCTAssertTrue(AppThemePalette.shouldMigratePersistedRawValue("coolBlue"))
        XCTAssertTrue(AppThemePalette.shouldMigratePersistedRawValue("pink"))
        XCTAssertFalse(AppThemePalette.shouldMigratePersistedRawValue("oceanBlue"))
        XCTAssertFalse(AppThemePalette.shouldMigratePersistedRawValue("blossomPink"))
    }

    func testDisplayNamesMatchFormaProductCopy() {
        XCTAssertEqual(AppThemePalette.oceanBlue.displayName, "Ocean Blue")
        XCTAssertEqual(AppThemePalette.blossomPink.displayName, "Blossom Pink")
        XCTAssertEqual(AppThemePalette.emeraldGreen.displayName, "Emerald Green")
        XCTAssertEqual(AppThemePalette.sunsetOrange.displayName, "Sunset Orange")
    }

    func testDescriptionsMatchFormaProductCopy() {
        XCTAssertEqual(AppThemePalette.oceanBlue.description, "Calm ocean blues.")
        XCTAssertEqual(AppThemePalette.blossomPink.description, "Warm blossom pinks.")
        XCTAssertEqual(AppThemePalette.emeraldGreen.description, "Fresh emerald greens.")
        XCTAssertEqual(AppThemePalette.sunsetOrange.description, "Warm sunset oranges.")
    }

    func testAccessibilityLabelsIncludeSelectionState() {
        XCTAssertEqual(
            AppThemePalette.blossomPink.accessibilityLabel(isSelected: true),
            "Blossom Pink, selected, Warm blossom pinks"
        )
        XCTAssertEqual(
            AppThemePalette.emeraldGreen.accessibilityLabel(isSelected: false),
            "Emerald Green, Fresh emerald greens"
        )
    }

    func testPreferencesRoundTripPreservesPalette() throws {
        let suiteName = "AppThemePaletteTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let original = AppThemePreferences(appearance: .dark, palette: .emeraldGreen)
        original.write(to: defaults)

        let loaded = AppThemePreferences(userDefaults: defaults)
        XCTAssertEqual(loaded.palette, .emeraldGreen)
        XCTAssertEqual(defaults.string(forKey: AppThemePreferences.PersistenceKey.palette), "emeraldGreen")
    }

    func testPreferencesReadLegacyPaletteKey() {
        let preferences = AppThemePreferences(
            appearanceRawValue: "dark",
            paletteRawValue: "defaultForma"
        )
        XCTAssertEqual(preferences.palette, .oceanBlue)
    }
}
