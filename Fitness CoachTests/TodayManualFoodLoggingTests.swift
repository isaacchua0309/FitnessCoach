//
//  TodayManualFoodLoggingTests.swift
//  Fitness CoachTests
//
//  Forma — Native manual food logging from Today (form validation + coordinator save path).
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class TodayManualFoodLoggingTests: XCTestCase {

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

    // MARK: - Form validation

    func testInvalidCaloriesSurfacesNonShamingError() {
        var formState = makeFormState(calories: "not-a-number")

        XCTAssertThrowsError(try formState.makeFoodDraft()) { error in
            XCTAssertEqual(error as? FoodEntryFormError, .invalidCalories)
            XCTAssertEqual(error.localizedDescription, "Calories must be zero or more.")
        }
    }

    func testInvalidMacrosSurfacesNonShamingErrors() {
        var proteinForm = makeFormState(protein: "-2")
        XCTAssertThrowsError(try proteinForm.makeFoodDraft()) { error in
            XCTAssertEqual(error as? FoodEntryFormError, .invalidProtein)
            XCTAssertEqual(error.localizedDescription, "Protein must be zero or more.")
        }

        var carbsForm = makeFormState(carbs: "abc")
        XCTAssertThrowsError(try carbsForm.makeFoodDraft()) { error in
            XCTAssertEqual(error as? FoodEntryFormError, .invalidCarbs)
            XCTAssertEqual(error.localizedDescription, "Carbs must be zero or more.")
        }

        var fatForm = makeFormState(fat: "-1")
        XCTAssertThrowsError(try fatForm.makeFoodDraft()) { error in
            XCTAssertEqual(error as? FoodEntryFormError, .invalidFat)
            XCTAssertEqual(error.localizedDescription, "Fat must be zero or more.")
        }
    }

    // MARK: - Coordinator save path

    func testValidSaveDismissesSheetRecalculatesTotalsAndNotifiesRefresh() throws {
        coordinator.performQuickAction(.manualEntry)
        XCTAssertNotNil(coordinator.logMealPresentation)

        let refreshTokenBefore = harness.refreshCenter.refreshToken

        coordinator.saveMeal(from: makeFormState(
            name: "Turkey sandwich",
            calories: "420",
            protein: "28",
            carbs: "38",
            fat: "14",
            mealType: .lunch
        ))

        XCTAssertNil(coordinator.logMealPresentation)
        XCTAssertNil(coordinator.lastErrorMessage)

        let entries = try harness.actionCenter.getFoodEntries(for: harness.today)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.name, "Turkey sandwich")
        XCTAssertEqual(entries.first?.mealType, .lunch)
        XCTAssertEqual(entries.first?.calories, 420)
        XCTAssertEqual(entries.first?.protein, 28)
        XCTAssertEqual(entries.first?.carbs, 38)
        XCTAssertEqual(entries.first?.fat, 14)

        let log = try XCTUnwrap(try harness.dailyLogService.getLog(for: harness.today))
        XCTAssertEqual(log.totals.calories, 420)
        XCTAssertEqual(log.totals.protein, 28)
        XCTAssertEqual(log.totals.carbs, 38)
        XCTAssertEqual(log.totals.fat, 14)

        XCTAssertEqual(harness.refreshCenter.refreshToken, refreshTokenBefore + 1)
    }

    func testInvalidCaloriesKeepsSheetOpenWithError() {
        coordinator.performQuickAction(.manualEntry)
        let presentationID = coordinator.logMealPresentation?.id

        coordinator.saveMeal(from: makeFormState(calories: "-10"))

        XCTAssertEqual(coordinator.logMealPresentation?.id, presentationID)
        XCTAssertEqual(coordinator.lastErrorMessage, FoodEntryFormError.invalidCalories.localizedDescription)
        XCTAssertEqual(try harness.actionCenter.getFoodEntries(for: harness.today).count, 0)
    }

    func testInvalidMacrosKeepsSheetOpenWithError() {
        coordinator.performQuickAction(.manualEntry)
        let presentationID = coordinator.logMealPresentation?.id

        coordinator.saveMeal(from: makeFormState(protein: "lots"))

        XCTAssertEqual(coordinator.logMealPresentation?.id, presentationID)
        XCTAssertEqual(coordinator.lastErrorMessage, FoodEntryFormError.invalidProtein.localizedDescription)
        XCTAssertEqual(try harness.actionCenter.getFoodEntries(for: harness.today).count, 0)
    }

    func testTotalsRecalculateWhenAddingMultipleMeals() throws {
        coordinator.saveMeal(from: makeFormState(
            name: "Breakfast",
            calories: "300",
            protein: "20",
            carbs: "30",
            fat: "10",
            mealType: .breakfast
        ))
        coordinator.saveMeal(from: makeFormState(
            name: "Lunch",
            calories: "500",
            protein: "35",
            carbs: "45",
            fat: "18",
            mealType: .lunch
        ))

        let log = try XCTUnwrap(try harness.dailyLogService.getLog(for: harness.today))
        XCTAssertEqual(log.totals.calories, 800)
        XCTAssertEqual(log.totals.protein, 55)
        XCTAssertEqual(log.totals.carbs, 75)
        XCTAssertEqual(log.totals.fat, 28)
        XCTAssertEqual(try harness.actionCenter.getFoodEntries(for: harness.today).count, 2)
    }

    func testRefreshNotificationOnlyOnSuccessfulSave() throws {
        let tokenBefore = harness.refreshCenter.refreshToken

        coordinator.saveMeal(from: makeFormState(calories: "bad"))
        XCTAssertEqual(harness.refreshCenter.refreshToken, tokenBefore)

        coordinator.saveMeal(from: makeFormState())
        XCTAssertEqual(harness.refreshCenter.refreshToken, tokenBefore + 1)
    }

    func testEmptyMacrosDefaultToZero() throws {
        var formState = makeFormState(
            name: "Apple",
            calories: "95",
            protein: "",
            carbs: "",
            fat: ""
        )

        let draft = try formState.makeFoodDraft()
        XCTAssertEqual(draft.protein, 0)
        XCTAssertEqual(draft.carbs, 0)
        XCTAssertEqual(draft.fat, 0)

        coordinator.saveMeal(from: formState)

        let log = try XCTUnwrap(try harness.dailyLogService.getLog(for: harness.today))
        XCTAssertEqual(log.totals.calories, 95)
        XCTAssertEqual(log.totals.protein, 0)
    }

    // MARK: - Helpers

    private func makeFormState(
        name: String = "Grilled chicken",
        calories: String = "350",
        protein: String = "42",
        carbs: String = "0",
        fat: String = "8",
        mealType: MealType = .lunch
    ) -> FoodEntryFormState {
        var state = FoodEntryFormState()
        state.name = name
        state.caloriesText = calories
        state.proteinText = protein
        state.carbsText = carbs
        state.fatText = fat
        state.mealType = mealType
        return state
    }
}
