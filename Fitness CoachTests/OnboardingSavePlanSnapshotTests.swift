//
//  OnboardingSavePlanSnapshotTests.swift
//  Fitness CoachTests
//
//  Forma — Renders protect-progress layouts for visual regression review.
//  Set SAVE_PLAN_SNAPSHOTS=1 to write PNGs into screenshots/save-plan/.
//

import SwiftUI
import XCTest
@testable import Fitness_Coach

@MainActor
final class OnboardingSavePlanSnapshotTests: XCTestCase {

    private var writesSnapshots: Bool {
        ProcessInfo.processInfo.environment["SAVE_PLAN_SNAPSHOTS"] == "1"
    }

    func testSavePlanSnapshotMatrix() throws {
        guard writesSnapshots else {
            throw XCTSkip("Set SAVE_PLAN_SNAPSHOTS=1 to export protect-progress screenshots.")
        }

        let fixtures: [(name: String, size: CGSize, dynamicType: DynamicTypeSize)] = [
            ("iphone-se", CGSize(width: 375, height: 667), .large),
            ("iphone-pro-max", CGSize(width: 430, height: 932), .large),
            ("iphone-se-accessibility", CGSize(width: 375, height: 667), .accessibility2)
        ]

        for fixture in fixtures {
            try exportSnapshot(
                name: fixture.name,
                size: fixture.size,
                dynamicTypeSize: fixture.dynamicType
            )
        }
    }

    private func exportSnapshot(
        name: String,
        size: CGSize,
        dynamicTypeSize: DynamicTypeSize
    ) throws {
        let view = OnboardingSavePlanStepView(
            requiresGoogleSignIn: true,
            isBusy: false,
            errorMessage: nil,
            planRecap: OnboardingPreviewData.planRevealState,
            onContinue: {},
            onBack: {}
        )
        .frame(width: size.width, height: size.height)
        .background(OnboardingTheme.background)
        .dynamicTypeSize(dynamicTypeSize)
        .formaThemePreview()

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
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return repoRoot.appendingPathComponent("screenshots/save-plan/after", isDirectory: true)
    }
}
