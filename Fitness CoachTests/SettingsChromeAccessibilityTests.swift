//
//  SettingsChromeAccessibilityTests.swift
//  Fitness CoachTests
//
//  Forma — Settings visual polish and accessibility contract tests.
//

import XCTest
@testable import Fitness_Coach

final class SettingsChromeAccessibilityTests: XCTestCase {

    func testLayoutConstantsMeetMinimumTouchTargets() {
        XCTAssertGreaterThanOrEqual(
            SettingsChromeAccessibility.minimumRowTouchTarget,
            FormaTokens.Layout.minTouchTarget
        )
        XCTAssertGreaterThanOrEqual(
            SettingsChromeAccessibility.minimumActionButtonHeight,
            FormaTokens.Layout.minTouchTarget
        )
    }

    func testDetailLayoutUsesReadableWidth() {
        XCTAssertEqual(SettingsChromeAccessibility.detailSectionSpacing, 16)
        XCTAssertLessThanOrEqual(
            SettingsChromeAccessibility.detailPageTopPadding,
            FormaTokens.Spacing.md
        )
    }

    func testRowAccessibilityPolicyDocumentsAffordances() {
        XCTAssertTrue(SettingsRowAccessibilityPolicy.includesDisclosureForButtonRows)
        XCTAssertTrue(SettingsRowAccessibilityPolicy.usesSystemNavigationChevron)
        XCTAssertTrue(SettingsRowAccessibilityPolicy.destructiveUsesFullContrastWhenEnabled)
        XCTAssertTrue(SettingsRowAccessibilityPolicy.supportsDynamicTypeWrapping)
        XCTAssertTrue(SettingsRowAccessibilityPolicy.supportsLongEmailWrapping)
    }

    func testRowAccessibilityFormatterCombinesTitleAndStatus() {
        XCTAssertEqual(
            SettingsRowAccessibilityFormatter.label(title: "Units", status: "Metric"),
            "Units, Metric"
        )
        XCTAssertEqual(
            SettingsRowAccessibilityFormatter.label(title: "Version", status: nil),
            "Version"
        )
    }

    func testRowAccessibilityFormatterDescribesExternalActions() {
        XCTAssertEqual(
            SettingsRowAccessibilityFormatter.buttonHint(opensExternally: true),
            "Opens in browser"
        )
        XCTAssertEqual(
            SettingsRowAccessibilityFormatter.buttonHint(opensExternally: false),
            "Opens details"
        )
    }

    func testDoneCopyUsesSharedProductString() {
        XCTAssertEqual(FormaProductCopy.Common.done, "Done")
        XCTAssertEqual(FormaProductCopy.Settings.Hub.doneAccessibilityLabel, "Done")
    }
}
