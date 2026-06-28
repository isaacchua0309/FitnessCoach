//
//  TodayFoodEntryEditTests.swift
//  Fitness CoachTests
//
//  Forma — Edit and delete food entries from Today.
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class TodayFoodEntryEditTests: XCTestCase {

    private var harness: FitnessActionCenterTestSupport.Harness!
    private var coordinator: TodayActionCoordinator!

    override func setUp() async throws {
        harness = try FitnessActionCenterTestSupport.makeHarness(cloudUID: nil)
        coordinator = TodayActionCoordinator(
            actionCenter: harness.actionCenter,
            logDate: { [harness] in harness.today }
        )
        try harness.seedProfile()
        _ = try harness.actionCenter.ensureTodayLog()
    }

    func testRowTapOpensEditPresentation() throws {
        let entry = try seedEntry(name: "Salad", mealType: .lunch, calories: 350, protein: 22)

        coordinator.openEditFood(entry)

        XCTAssertEqual(coordinator.editFoodPresentation?.entry.id, entry.id)
        XCTAssertNil(coordinator.foodEditErrorMessage)
    }

    func testSaveEditUpdatesTotals() throws {
        let entry = try seedEntry(name: "Salad", mealType: .lunch, calories: 350, protein: 22)
        coordinator.openEditFood(entry)

        let refreshBefore = harness.refreshCenter.refreshToken
        var formState = FoodEntryFormState(foodEntry: entry)
        formState.name = "Large salad"
        formState.caloriesText = "480"
        formState.proteinText = "30"

        coordinator.saveFoodEdit(from: formState)

        XCTAssertNil(coordinator.editFoodPresentation)
        XCTAssertNil(coordinator.foodEditErrorMessage)

        let updated = try XCTUnwrap(try harness.actionCenter.getFoodEntries(for: harness.today).first)
        XCTAssertEqual(updated.name, "Large salad")
        XCTAssertEqual(updated.calories, 480)
        XCTAssertEqual(updated.protein, 30)

        let log = try XCTUnwrap(try harness.dailyLogService.getLog(for: harness.today))
        XCTAssertEqual(log.totals.calories, 480)
        XCTAssertEqual(log.totals.protein, 30)
        XCTAssertEqual(harness.refreshCenter.refreshToken, refreshBefore + 1)
    }

    func testDeleteRemovesRowAndRecalculatesTotals() throws {
        _ = try seedEntry(name: "Breakfast", mealType: .breakfast, calories: 300, protein: 20)
        let lunch = try seedEntry(name: "Lunch", mealType: .lunch, calories: 500, protein: 35)

        let refreshBefore = harness.refreshCenter.refreshToken
        coordinator.requestDeleteFood(lunch)
        coordinator.confirmDeleteFood()

        XCTAssertNil(coordinator.pendingDeleteFoodEntry)
        XCTAssertNil(coordinator.editFoodPresentation)
        XCTAssertEqual(try harness.actionCenter.getFoodEntries(for: harness.today).count, 1)

        let log = try XCTUnwrap(try harness.dailyLogService.getLog(for: harness.today))
        XCTAssertEqual(log.totals.calories, 300)
        XCTAssertEqual(log.totals.protein, 20)
        XCTAssertEqual(harness.refreshCenter.refreshToken, refreshBefore + 1)
    }

    func testDeleteConfirmationCancelKeepsEntry() throws {
        let entry = try seedEntry(name: "Snack", mealType: .snack, calories: 180, protein: 8)
        let refreshBefore = harness.refreshCenter.refreshToken

        coordinator.requestDeleteFood(entry)
        XCTAssertNotNil(coordinator.pendingDeleteFoodEntry)

        coordinator.cancelDeleteFood()

        XCTAssertNil(coordinator.pendingDeleteFoodEntry)
        XCTAssertEqual(try harness.actionCenter.getFoodEntries(for: harness.today).count, 1)
        XCTAssertEqual(harness.refreshCenter.refreshToken, refreshBefore)

        let log = try XCTUnwrap(try harness.dailyLogService.getLog(for: harness.today))
        XCTAssertEqual(log.totals.calories, 180)
    }

    func testAIEntryEditMarksSourceCorrected() throws {
        let entry = try seedEntry(
            name: "AI meal",
            mealType: .dinner,
            calories: 600,
            protein: 40,
            source: .aiTextEstimate,
            confidence: .medium
        )
        coordinator.openEditFood(entry)

        var formState = FoodEntryFormState(foodEntry: entry)
        formState.caloriesText = "650"
        coordinator.saveFoodEdit(from: formState)

        let updated = try XCTUnwrap(try harness.actionCenter.getFoodEntries(for: harness.today).first)
        XCTAssertEqual(updated.source, .corrected)
        XCTAssertEqual(updated.calories, 650)
    }

    // MARK: - Helpers

    @discardableResult
    private func seedEntry(
        name: String,
        mealType: MealType,
        calories: Int,
        protein: Double,
        source: FoodEntrySource = .manual,
        confidence: ConfidenceLevel = .high
    ) throws -> FoodEntry {
        try harness.actionCenter.logFood(
            FoodDraft(
                mealType: mealType,
                name: name,
                quantity: 1,
                unit: "serving",
                calories: calories,
                protein: protein,
                carbs: 0,
                fat: 0,
                fiber: nil,
                sodium: nil,
                source: source,
                confidence: confidence,
                imageUrl: nil,
                notes: nil
            ),
            date: harness.today
        )
    }
}
