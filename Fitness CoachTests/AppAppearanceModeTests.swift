//
//  AppAppearanceModeTests.swift
//  Fitness CoachTests
//
//  Forma — AppAppearanceMode defaults, persistence, and display copy.
//

import XCTest
@testable import Fitness_Coach

final class AppAppearanceModeTests: XCTestCase {

    func testLegacyDefaultIsDark() {
        XCTAssertEqual(AppAppearanceMode.legacyDefault, .dark)
        XCTAssertEqual(AppThemePreferences.default.appearance, .dark)
    }

    func testLoadsValidPersistedRawValues() {
        XCTAssertEqual(AppAppearanceMode(storedRawValue: "system"), .system)
        XCTAssertEqual(AppAppearanceMode(storedRawValue: "light"), .light)
        XCTAssertEqual(AppAppearanceMode(storedRawValue: "dark"), .dark)
    }

    func testFallsBackToDarkForMissingOrUnknownRawValue() {
        XCTAssertEqual(AppAppearanceMode(storedRawValue: nil), .dark)
        XCTAssertEqual(AppAppearanceMode(storedRawValue: "sepia"), .dark)
    }

    func testDisplayNamesMatchFormaProductCopy() {
        XCTAssertEqual(AppAppearanceMode.system.displayName, "System")
        XCTAssertEqual(AppAppearanceMode.light.displayName, "Light")
        XCTAssertEqual(AppAppearanceMode.dark.displayName, "Dark")
        XCTAssertEqual(
            AppAppearanceMode.dark.displayName,
            FormaProductCopy.Settings.Theme.appearanceTitle(for: .dark)
        )
    }

    func testDescriptionsMatchFormaProductCopy() {
        XCTAssertEqual(AppAppearanceMode.system.description, "Match device appearance")
        XCTAssertEqual(AppAppearanceMode.light.description, "Always use light appearance")
        XCTAssertEqual(AppAppearanceMode.dark.description, "Always use dark appearance")
    }

    func testAccessibilityLabelsIncludeSelectionState() {
        XCTAssertEqual(
            AppAppearanceMode.dark.accessibilityLabel(isSelected: true),
            "Dark, selected, Always use dark appearance"
        )
        XCTAssertEqual(
            AppAppearanceMode.light.accessibilityLabel(isSelected: false),
            "Light, Always use light appearance"
        )
    }

    func testSettingsSelectableCasesRespectShippingPolicy() {
        XCTAssertEqual(AppAppearanceMode.settingsSelectableCases, [.dark])
        XCTAssertFalse(AppThemeShippingPolicy.shipsLightAndSystemAppearance)
    }
}
