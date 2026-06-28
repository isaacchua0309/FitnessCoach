//
//  OnboardingPlanRevealSnapshotTests.swift
//  Fitness CoachTests
//
//  Forma — Renders plan reveal layouts for visual regression review.
//  Set PLAN_REVEAL_SNAPSHOTS=1 to write PNGs into screenshots/plan-reveal/.
//

import SwiftUI
import XCTest
@testable import Fitness_Coach

@MainActor
final class OnboardingPlanRevealSnapshotTests: XCTestCase {

    private var writesSnapshots: Bool {
        if ProcessInfo.processInfo.environment["PLAN_REVEAL_SNAPSHOTS"] == "1" {
            return true
        }
        return FileManager.default.fileExists(atPath: "/tmp/export-plan-reveal")
    }

    func testPlanRevealSnapshotMatrix() throws {
        guard writesSnapshots else {
            throw XCTSkip("Set PLAN_REVEAL_SNAPSHOTS=1 to export plan reveal screenshots.")
        }

        guard let revealState = OnboardingPreviewData.planRevealState else {
            XCTFail("Missing preview reveal state")
            return
        }
        let plan = OnboardingPreviewData.generatedPlan

        let fixtures: [(name: String, size: CGSize, dynamicType: DynamicTypeSize)] = [
            ("iphone-se-cut", CGSize(width: 375, height: 667), .large),
            ("iphone-16-cut", CGSize(width: 390, height: 844), .large),
            ("iphone-pro-max-cut", CGSize(width: 430, height: 932), .large),
            ("iphone-se-xl-type", CGSize(width: 375, height: 667), .xLarge)
        ]

        for fixture in fixtures {
            try exportSnapshot(
                name: fixture.name,
                size: fixture.size,
                dynamicTypeSize: fixture.dynamicType,
                revealState: revealState,
                plan: plan
            )
        }
    }

    private func exportSnapshot(
        name: String,
        size: CGSize,
        dynamicTypeSize: DynamicTypeSize,
        revealState: OnboardingPlanRevealState,
        plan: CalorieTargetResult
    ) throws {
        let view = OnboardingPlanRevealProductionPreviewShell(
            revealState: revealState,
            plan: plan
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
        return repoRoot.appendingPathComponent("screenshots/plan-reveal", isDirectory: true)
    }
}
