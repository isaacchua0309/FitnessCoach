//
//  NutritionEstimateCardSnapshotTests.swift
//  Fitness CoachTests
//

import SwiftUI
import XCTest
@testable import Fitness_Coach

@MainActor
final class NutritionEstimateCardSnapshotTests: XCTestCase {

    private var writesSnapshots: Bool {
        ProcessInfo.processInfo.environment["NUTRITION_ESTIMATE_SNAPSHOTS"] == "1"
    }

    func testLightModeLayout() throws {
        try assertSnapshot(
            name: "nutrition_estimate_light",
            appearance: .light,
            state: Self.sampleState(longName: false)
        )
    }

    func testDarkModeLayout() throws {
        try assertSnapshot(
            name: "nutrition_estimate_dark",
            appearance: .dark,
            state: Self.sampleState(longName: false)
        )
    }

    func testSmallScreenLongFoodName() throws {
        try assertSnapshot(
            name: "nutrition_estimate_small_long_name",
            appearance: .light,
            width: 320,
            state: Self.sampleState(longName: true, includeMacros: false, confidence: .low)
        )
    }

    private func assertSnapshot(
        name: String,
        appearance: AppAppearanceMode,
        width: CGFloat = 375,
        state: NutritionEstimateCardState
    ) throws {
        guard writesSnapshots else {
            throw XCTSkip("Set NUTRITION_ESTIMATE_SNAPSHOTS=1 to write PNG snapshots.")
        }

        let view = NutritionEstimateCard(state: state)
            .padding()
            .frame(width: width)
            .background(CoachDesignTokens.Color.background)
            .formaThemePreview(appearance: appearance)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let image = renderer.uiImage else {
            XCTFail("Failed to render snapshot")
            return
        }

        let directory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("screenshots/nutrition-estimate", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("\(name).png")
        guard let data = image.pngData() else {
            XCTFail("Failed to encode PNG")
            return
        }
        try data.write(to: url)
    }

    private static func sampleState(
        longName: Bool,
        includeMacros: Bool = true,
        confidence: AIConfidence = .high
    ) -> NutritionEstimateCardState {
        NutritionEstimateCardState(
            id: UUID(),
            foodName: longName ? "Double quarter pounder with extra cheese" : "Big Mac",
            displayEmoji: "🍔",
            servingDescription: "1 standard burger",
            caloriesDisplay: "550 kcal",
            proteinDisplay: includeMacros ? "Protein 25g" : nil,
            carbsDisplay: includeMacros ? "Carbs 45g" : nil,
            fatDisplay: includeMacros ? "Fat 30g" : nil,
            confidenceTitle: confidence == .high ? "High confidence" : "Low confidence",
            confidenceSubtitle: "Known/common food estimate",
            coachSummary: "Estimated fit for today.",
            coachTip: "Skip fries to save ~300 kcal.",
            caveats: ["Values may vary slightly."],
            todayContext: includeMacros ? NutritionEstimateTodayContext(
                caloriesAfterLine: "Calories after this: 1,420 / 2,086 kcal",
                caloriesRemainingLine: "Remaining: 666 kcal",
                proteinLine: "Protein: 112 / 198g"
            ) : nil,
            suggestedActions: [
                NutritionSuggestedAction(title: "Log Meal", type: .logMeal),
                NutritionSuggestedAction(title: "Add fries", type: .addCommonSide)
            ],
            sourceType: .branded,
            confidenceLevel: confidence,
            hasMacros: includeMacros,
            hasTodayContext: includeMacros,
            logMealPayload: nil
        )
    }
}
