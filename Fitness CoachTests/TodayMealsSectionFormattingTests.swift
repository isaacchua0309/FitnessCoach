//
//  TodayMealsSectionFormattingTests.swift
//  Fitness CoachTests
//
//  Forma — Display formatting for the Today meals section.
//

import XCTest
@testable import Fitness_Coach

final class TodayMealsSectionFormattingTests: XCTestCase {

    func testEmptyMealsRenderAsReady() {
        let display = TodayMealsSectionFormatting.rowDisplayModel(
            for: group(mealType: .breakfast, isLogged: false)
        )

        XCTAssertEqual(display.statusLine, "Ready")
        XCTAssertTrue(display.showsAddAction)
        XCTAssertFalse(display.showsCheckmark)
        XCTAssertNil(display.detailLine)
    }

    func testLoggedMealShowsCaloriesAndProteinOnSeparateLines() {
        let display = TodayMealsSectionFormatting.rowDisplayModel(
            for: group(
                mealType: .lunch,
                isLogged: true,
                totalCalories: 482,
                totalProtein: 38
            )
        )

        XCTAssertEqual(display.statusLine, "482 kcal")
        XCTAssertEqual(display.detailLine, "38g protein")
        XCTAssertTrue(display.showsCheckmark)
        XCTAssertFalse(display.showsAddAction)
    }

    func testSnacksMarkedOptional() {
        let emptySnacks = TodayMealsSectionFormatting.rowDisplayModel(
            for: group(mealType: .snack, isLogged: false, isOptional: true)
        )
        let loggedSnacks = TodayMealsSectionFormatting.rowDisplayModel(
            for: group(
                mealType: .snack,
                isLogged: true,
                totalCalories: 210,
                totalProtein: 20,
                isOptional: true
            )
        )

        XCTAssertTrue(emptySnacks.isOptional)
        XCTAssertEqual(emptySnacks.title, "Snacks")
        XCTAssertTrue(emptySnacks.accessibilityLabel.contains("Optional"))

        XCTAssertTrue(loggedSnacks.isOptional)
        XCTAssertEqual(loggedSnacks.title, "Snacks")
        XCTAssertTrue(loggedSnacks.accessibilityLabel.contains("Optional"))
    }

    @MainActor
    func testAddMealRoutesToCoachMealLogging() {
        var launchedIntents: [CoachLaunchIntent] = []
        let coordinator = TodayActionCoordinator(
            actionCenter: try! FitnessActionCenterTestSupport.makeHarness().actionCenter
        )
        coordinator.onOpenCoach = { launchedIntents.append($0) }

        coordinator.logMeal(for: .breakfast)
        coordinator.logMeal(for: .lunch)
        coordinator.logMeal(for: .dinner)
        coordinator.logMeal(for: .snack)

        XCTAssertEqual(
            launchedIntents,
            [
                .logMeal(mealType: .breakfast),
                .logMeal(mealType: .lunch),
                .logMeal(mealType: .dinner),
                .logMeal(mealType: .snack)
            ]
        )
    }

    @MainActor
    func testEditRouteOpensExistingEditPresentation() throws {
        let harness = try FitnessActionCenterTestSupport.makeHarness()
        try harness.seedProfile()
        _ = try harness.actionCenter.ensureTodayLog()

        let coordinator = TodayActionCoordinator(
            actionCenter: harness.actionCenter,
            logDate: { harness.today }
        )

        let entry = try harness.actionCenter.logFood(
            FoodDraft(
                mealType: .lunch,
                name: "Chicken bowl",
                quantity: 1,
                unit: "bowl",
                calories: 482,
                protein: 38,
                carbs: 40,
                fat: 12
            ),
            date: harness.today
        )

        coordinator.openEditFood(entry)

        XCTAssertEqual(coordinator.editFoodPresentation?.entry.id, entry.id)
    }

    // MARK: - Helpers

    private func group(
        mealType: MealType,
        isLogged: Bool,
        totalCalories: Int = 0,
        totalProtein: Double = 0,
        isOptional: Bool = false,
        entryCount: Int = 1
    ) -> TodayMealGroupState {
        let entries: [FoodEntry]
        if isLogged {
            entries = (0..<entryCount).map { index in
                FoodEntry(
                    id: UUID(),
                    dailyLogId: UUID(),
                    mealType: mealType,
                    name: "Item \(index + 1)",
                    quantity: 1,
                    unit: "serving",
                    calories: totalCalories / max(entryCount, 1),
                    protein: totalProtein / Double(max(entryCount, 1)),
                    carbs: 0,
                    fat: 0,
                    fiber: nil,
                    sodium: nil,
                    source: .manual,
                    confidence: .high,
                    imageUrl: nil,
                    notes: nil,
                    createdAt: Date(),
                    updatedAt: Date()
                )
            }
        } else {
            entries = []
        }

        return TodayMealGroupState(
            mealType: mealType,
            entries: entries,
            totalCalories: totalCalories,
            totalProtein: totalProtein,
            isLogged: isLogged,
            isPastDueMissing: false,
            isOptional: isOptional
        )
    }
}
