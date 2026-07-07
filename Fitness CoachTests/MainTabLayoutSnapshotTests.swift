//
//  MainTabLayoutSnapshotTests.swift
//  Fitness CoachTests
//
//  Forma — Optional PNG exports for shared main-tab layout previews.
//  Set MAIN_TAB_LAYOUT_SNAPSHOTS=1 to write into screenshots/main-tab-layout/.
//

import SwiftUI
import XCTest
@testable import Fitness_Coach

@MainActor
final class MainTabLayoutSnapshotTests: XCTestCase {

    private var writesSnapshots: Bool {
        ProcessInfo.processInfo.environment["MAIN_TAB_LAYOUT_SNAPSHOTS"] == "1"
    }

    func testMainTabLayoutSnapshotMatrix() throws {
        guard writesSnapshots else {
            throw XCTSkip("Set MAIN_TAB_LAYOUT_SNAPSHOTS=1 to export main-tab layout screenshots.")
        }

        let palettes: [AppThemePalette] = [.oceanBlue, .blossomPink]

        for fixture in MainTabLayoutSnapshotFixture.allCases {
            for palette in palettes {
                let name = "\(fixture.rawValue)-\(palette.rawValue)"
                try exportSnapshot(name: name, fixture: fixture, palette: palette)
            }
        }
    }

    private func exportSnapshot(
        name: String,
        fixture: MainTabLayoutSnapshotFixture,
        palette: AppThemePalette
    ) throws {
        let view = MainTabLayoutPreviewScreens.snapshotView(for: fixture, palette: palette)
            .frame(
                width: MainTabLayoutPreviewScreens.Metrics.previewWidth,
                height: fixture.exportHeight
            )

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
            .appendingPathComponent("screenshots/main-tab-layout", isDirectory: true)
    }
}
