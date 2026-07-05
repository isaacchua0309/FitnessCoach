//
//  ThemeSettingsPickerLiveUpdateTests.swift
//  Fitness CoachTests
//
//  Forma — Guardrails for live ThemeManager updates from Settings theme picker.
//

import XCTest
@testable import Fitness_Coach

final class ThemeSettingsPickerLiveUpdateTests: XCTestCase {

    func testSetThemeUpdatesSelectedThemeAndRevisionImmediately() async {
        await MainActor.run {
            let store = ThemeStore(
                userDefaults: ThemeTestSupport.makeIsolatedDefaults(
                    suiteNamePrefix: "ThemeSettingsPickerLiveUpdateTests"
                )
            )
            let initialRevision = store.themeRevision

            store.setTheme(.blossomPink)

            XCTAssertEqual(store.selectedTheme, .blossomPink)
            XCTAssertEqual(store.palette, .blossomPink)
            XCTAssertGreaterThan(store.themeRevision, initialRevision)
        }
    }

    func testThemeSettingsPickerUsesLiveThemeManagerBinding() throws {
        let source = try String(
            contentsOf: ThemeTestSupport.repositoryRoot().appendingPathComponent(
                "Fitness Coach/Features/Settings/UI/ThemeSettingsView.swift"
            ),
            encoding: .utf8
        )
        let productionSource = source.components(separatedBy: "#Preview").first ?? source

        XCTAssertTrue(
            productionSource.contains("@EnvironmentObject private var themeManager: ThemeManager"),
            "Theme settings must observe the shared ThemeManager environment object."
        )
        XCTAssertTrue(
            productionSource.contains("get: { themeManager.selectedTheme }"),
            "Theme picker binding must read themeManager.selectedTheme."
        )
        XCTAssertTrue(
            productionSource.contains("set: { themeManager.setTheme($0) }"),
            "Theme picker binding must call themeManager.setTheme."
        )
        XCTAssertTrue(
            productionSource.contains("themeManager.setTheme(palette)"),
            "Theme picker selection must call themeManager.setTheme."
        )
        XCTAssertTrue(
            productionSource.contains("themeManager.selectedTheme == palette"),
            "Theme picker cards must derive selected state from themeManager.selectedTheme."
        )
        XCTAssertFalse(
            productionSource.contains("@AppStorage"),
            "Theme settings must not keep a competing @AppStorage selectedTheme."
        )
        XCTAssertFalse(
            productionSource.contains("@State private var selectedTheme"),
            "Theme settings must not keep local @State selectedTheme that only syncs on appear."
        )
    }

    func testSettingsRootObservesThemeManagerForThemeRowStatus() throws {
        let source = try String(
            contentsOf: ThemeTestSupport.repositoryRoot().appendingPathComponent(
                "Fitness Coach/Features/Settings/SettingsRootView.swift"
            ),
            encoding: .utf8
        )

        XCTAssertTrue(
            source.contains("@EnvironmentObject private var themeManager: ThemeManager"),
            "Settings root must observe ThemeManager for live theme row status."
        )
        XCTAssertTrue(
            source.contains("themeManager.selectedTheme"),
            "Settings root must build presentation state from themeManager.selectedTheme."
        )
        XCTAssertTrue(
            source.contains("themeManager.themeRevision"),
            "Settings root must invalidate when themeRevision changes."
        )
    }

    func testRootThemeModifierDependsOnThemeRevision() throws {
        let source = try String(
            contentsOf: ThemeTestSupport.repositoryRoot().appendingPathComponent(
                "Fitness Coach/DesignSystem/Theme/FormaThemeScreenModifier.swift"
            ),
            encoding: .utf8
        )

        XCTAssertTrue(
            source.contains("themeStore.themeRevision"),
            "Root theme injection must depend on themeRevision so tabs update live."
        )
    }
}
