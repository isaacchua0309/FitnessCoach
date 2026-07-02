//
//  ThemeSettingsSnapshotTests.swift
//  Fitness CoachTests
//
//  Forma — Optional visual export for the theme settings picker.
//  Set THEME_SETTINGS_SNAPSHOTS=1 to write PNGs into screenshots/theme-settings/.
//

import SwiftUI
import XCTest
@testable import Fitness_Coach

@MainActor
final class ThemeSettingsSnapshotTests: XCTestCase {

    private var writesSnapshots: Bool {
        ProcessInfo.processInfo.environment["THEME_SETTINGS_SNAPSHOTS"] == "1"
    }

    func testThemeSettingsSnapshotMatrix() throws {
        guard writesSnapshots else {
            throw XCTSkip("Set THEME_SETTINGS_SNAPSHOTS=1 to export theme settings screenshots.")
        }

        let fixtures: [(name: String, palette: AppThemePalette, appearance: AppAppearanceMode, size: CGSize)] = [
            ("ocean-blue-dark", .oceanBlue, .dark, CGSize(width: 390, height: 844)),
            ("emerald-green-dark", .emeraldGreen, .dark, CGSize(width: 390, height: 844)),
            ("sunset-orange-light", .sunsetOrange, .light, CGSize(width: 390, height: 844)),
            ("blossom-pink-accessibility", .blossomPink, .dark, CGSize(width: 390, height: 844))
        ]

        for fixture in fixtures {
            try exportSnapshot(
                name: fixture.name,
                palette: fixture.palette,
                appearance: fixture.appearance,
                size: fixture.size,
                dynamicTypeSize: fixture.name.contains("accessibility") ? .accessibility2 : .large
            )
        }
    }

    private func exportSnapshot(
        name: String,
        palette: AppThemePalette,
        appearance: AppAppearanceMode,
        size: CGSize,
        dynamicTypeSize: DynamicTypeSize
    ) throws {
        let defaults = UserDefaults(suiteName: "ThemeSettingsSnapshotTests.\(UUID().uuidString)")!
        let store = ThemeStore(userDefaults: defaults)
        store.setAppearance(appearance)
        store.setPalette(palette)

        let view = NavigationStack {
            ThemeSettingsView()
        }
        .environmentObject(store)
        .formaThemePreview(appearance: appearance, palette: palette)
        .frame(width: size.width, height: size.height)
        .dynamicTypeSize(dynamicTypeSize)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        guard let image = renderer.uiImage else {
            XCTFail("Failed to render snapshot for \(name)")
            return
        }

        let directory = snapshotDirectory()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("\(name).png")
        guard let data = image.pngData() else {
            XCTFail("Failed to encode PNG for \(name)")
            return
        }
        try data.write(to: url)
    }

    private func snapshotDirectory() -> URL {
        ThemeTestSupport.repositoryRoot(filePath: #filePath)
            .appendingPathComponent("screenshots/theme-settings", isDirectory: true)
    }
}
