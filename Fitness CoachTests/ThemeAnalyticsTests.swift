//
//  ThemeAnalyticsTests.swift
//  Fitness CoachTests
//
//  Forma — Theme settings analytics events, properties, and privacy guardrails.
//

import XCTest
@testable import Fitness_Coach

final class ThemeAnalyticsTests: XCTestCase {

    // MARK: - Event names

    func testThemeAnalyticsEventNames() {
        XCTAssertEqual(ThemeAnalyticsEvent.settingsViewed.rawValue, "theme_settings_viewed")
        XCTAssertEqual(ThemeAnalyticsEvent.appearanceModeChanged.rawValue, "appearance_mode_changed")
        XCTAssertEqual(ThemeAnalyticsEvent.paletteChanged.rawValue, "theme_palette_changed")
    }

    // MARK: - Properties

    func testSettingsViewedIncludesSourceOnly() {
        let parameters = ThemeAnalyticsProperties.settingsViewed().asParameters()
        XCTAssertEqual(parameters["source"], ThemeAnalyticsSource.settings.rawValue)
        XCTAssertNil(parameters["previousAppearance"])
        XCTAssertNil(parameters["newAppearance"])
        XCTAssertNil(parameters["previousPalette"])
        XCTAssertNil(parameters["newPalette"])
    }

    func testAppearanceChangePropertiesUseRawValues() {
        let parameters = ThemeAnalyticsProperties.appearanceChange(
            previous: .dark,
            new: .light
        ).asParameters()

        XCTAssertEqual(parameters["previousAppearance"], "dark")
        XCTAssertEqual(parameters["newAppearance"], "light")
        XCTAssertEqual(parameters["source"], "settings")
        XCTAssertNil(parameters["previousPalette"])
    }

    func testPaletteChangePropertiesUsePersistenceRawValues() {
        let parameters = ThemeAnalyticsProperties.paletteChange(
            previous: .oceanBlue,
            new: .blossomPink
        ).asParameters()

        XCTAssertEqual(parameters["previousPalette"], "oceanBlue")
        XCTAssertEqual(parameters["newPalette"], "blossomPink")
        XCTAssertEqual(parameters["source"], "settings")
        XCTAssertNil(parameters["previousAppearance"])
    }

    func testPropertiesExcludeIdentityAndHealthFields() {
        let bannedKeys = [
            "uid",
            "userId",
            "email",
            "name",
            "weight",
            "calorie",
            "health"
        ]

        let samples = [
            ThemeAnalyticsProperties.settingsViewed().asParameters(),
            ThemeAnalyticsProperties.appearanceChange(previous: .system, new: .dark).asParameters(),
            ThemeAnalyticsProperties.paletteChange(previous: .emeraldGreen, new: .oceanBlue).asParameters()
        ]

        for parameters in samples {
            for key in parameters.keys {
                let lowered = key.lowercased()
                for banned in bannedKeys {
                    XCTAssertFalse(
                        lowered.contains(banned),
                        "Unexpected analytics key \"\(key)\" containing \"\(banned)\""
                    )
                }
            }
        }
    }

    // MARK: - ThemeStore integration

    func testRecordSettingsViewedLogsEvent() async {
        await MainActor.run {
            let analytics = CapturingThemeAnalyticsLogger()
            let store = ThemeStore(
                userDefaults: UserDefaults(suiteName: "ThemeAnalyticsTests.viewed.\(UUID().uuidString)")!,
                analyticsLogger: analytics
            )

            store.recordSettingsViewed()

            XCTAssertTrue(analytics.contains(.settingsViewed))
            XCTAssertEqual(analytics.lastProperties(for: .settingsViewed)?["source"], "settings")
        }
    }

    func testSetAppearanceLogsChangeWithPreviousAndNewValues() async {
        await MainActor.run {
            let analytics = CapturingThemeAnalyticsLogger()
            let store = ThemeStore(
                userDefaults: UserDefaults(suiteName: "ThemeAnalyticsTests.appearance.\(UUID().uuidString)")!,
                analyticsLogger: analytics
            )
            XCTAssertEqual(store.appearance, .dark)

            store.setAppearance(.light)

            XCTAssertTrue(analytics.contains(.appearanceModeChanged))
            let properties = analytics.lastProperties(for: .appearanceModeChanged)
            XCTAssertEqual(properties?["previousAppearance"], "dark")
            XCTAssertEqual(properties?["newAppearance"], "light")
            XCTAssertEqual(properties?["source"], "settings")
        }
    }

    func testSetPaletteLogsChangeWithPreviousAndNewValues() async {
        await MainActor.run {
            let analytics = CapturingThemeAnalyticsLogger()
            let store = ThemeStore(
                userDefaults: UserDefaults(suiteName: "ThemeAnalyticsTests.palette.\(UUID().uuidString)")!,
                analyticsLogger: analytics
            )
            XCTAssertEqual(store.palette, .oceanBlue)

            store.setPalette(.blossomPink)

            XCTAssertTrue(analytics.contains(.paletteChanged))
            let properties = analytics.lastProperties(for: .paletteChanged)
            XCTAssertEqual(properties?["previousPalette"], "oceanBlue")
            XCTAssertEqual(properties?["newPalette"], "blossomPink")
            XCTAssertEqual(properties?["source"], "settings")
        }
    }

    func testRepeatedSelectionDoesNotLogDuplicateEvents() async {
        await MainActor.run {
            let analytics = CapturingThemeAnalyticsLogger()
            let store = ThemeStore(
                userDefaults: UserDefaults(suiteName: "ThemeAnalyticsTests.duplicate.\(UUID().uuidString)")!,
                analyticsLogger: analytics
            )

            store.setAppearance(.dark)
            store.setPalette(.oceanBlue)

            XCTAssertFalse(analytics.contains(.appearanceModeChanged))
            XCTAssertFalse(analytics.contains(.paletteChanged))
        }
    }
}
