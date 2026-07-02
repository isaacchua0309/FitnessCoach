//
//  ThemePalettePersistenceTests.swift
//  Fitness CoachTests
//
//  Forma — Theme palette persistence and migration rules.
//

import XCTest
@testable import Fitness_Coach

final class ThemePalettePersistenceTests: XCTestCase {

    func testCanonicalPaletteRequiresNoRewrite() {
        let result = ThemePalettePersistence.resolveStoredPalette(
            primaryRawValue: "emeraldGreen",
            legacyRawValue: nil
        )
        XCTAssertEqual(result.palette, .emeraldGreen)
        XCTAssertFalse(result.shouldRewriteCanonicalStore)
        XCTAssertNil(result.migrationReason)
    }

    func testLegacyDefaultMigratesToOceanBlue() {
        assertLegacyAlias("default", mapsTo: .oceanBlue)
    }

    func testLegacyBlueMigratesToOceanBlue() {
        assertLegacyAlias("blue", mapsTo: .oceanBlue)
    }

    func testLegacyPinkMigratesToBlossomPink() {
        assertLegacyAlias("pink", mapsTo: .blossomPink)
    }

    func testUnknownStoredValueFallsBackToOceanBlue() {
        let result = ThemePalettePersistence.resolveStoredPalette(
            primaryRawValue: "neon",
            legacyRawValue: nil
        )
        XCTAssertEqual(result.palette, .oceanBlue)
        XCTAssertTrue(result.shouldRewriteCanonicalStore)
        XCTAssertEqual(result.migrationReason, .unknownStoredValue("neon"))
    }

    func testLegacyStorageKeyRequiresCanonicalRewrite() {
        let result = ThemePalettePersistence.resolveStoredPalette(
            primaryRawValue: nil,
            legacyRawValue: "sunsetOrange"
        )
        XCTAssertEqual(result.palette, .sunsetOrange)
        XCTAssertTrue(result.shouldRewriteCanonicalStore)
        XCTAssertEqual(result.migrationReason, .legacyStorageKey)
    }

    // MARK: - Helpers

    private func assertLegacyAlias(
        _ stored: String,
        mapsTo expected: AppThemePalette,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let result = ThemePalettePersistence.resolveStoredPalette(
            primaryRawValue: stored,
            legacyRawValue: nil
        )
        XCTAssertEqual(result.palette, expected, file: file, line: line)
        XCTAssertTrue(result.shouldRewriteCanonicalStore, file: file, line: line)
        XCTAssertEqual(result.migrationReason, .legacyAlias(stored), file: file, line: line)
    }
}
