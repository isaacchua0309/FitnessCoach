//
//  TodayMealsGroupingTests.swift
//  Fitness CoachTests
//
//  Forma — Grouping logic for Today meals section.
//

import XCTest
@testable import Fitness_Coach

final class TodayMealsGroupingTests: XCTestCase {

    private let calendar = Calendar(identifier: .gregorian)

    private func date(hour: Int) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 6
        components.day = 28
        components.hour = hour
        return calendar.date(from: components)!
    }

    func testBreakfastOnly() throws {
        let entries = [Self.entry(name: "Oatmeal", mealType: .breakfast, calories: 320, protein: 18)]
        let section = TodayMealsGroupingEngine.build(
            entries: entries,
            date: date(hour: 14),
            calendar: calendar
        )

        let breakfast = try XCTUnwrap(group(.breakfast, in: section))
        XCTAssertTrue(breakfast.isLogged)
        XCTAssertEqual(breakfast.totalCalories, 320)
        XCTAssertEqual(breakfast.totalProtein, 18)
        XCTAssertFalse(breakfast.isPastDueMissing)

        let lunch = try XCTUnwrap(group(.lunch, in: section))
        XCTAssertFalse(lunch.isLogged)
        XCTAssertTrue(lunch.isPastDueMissing)

        let dinner = try XCTUnwrap(group(.dinner, in: section))
        XCTAssertFalse(dinner.isLogged)
        XCTAssertFalse(dinner.isPastDueMissing)
    }

    func testLunchMissingPastDue() throws {
        let entries = [Self.entry(name: "Eggs", mealType: .breakfast, calories: 280, protein: 20)]
        let section = TodayMealsGroupingEngine.build(
            entries: entries,
            date: date(hour: 16),
            calendar: calendar
        )

        let lunch = try XCTUnwrap(group(.lunch, in: section))
        XCTAssertFalse(lunch.isLogged)
        XCTAssertTrue(lunch.isPastDueMissing)

        let breakfast = try XCTUnwrap(group(.breakfast, in: section))
        XCTAssertTrue(breakfast.isLogged)
        XCTAssertFalse(breakfast.isPastDueMissing)
    }

    func testSnacksGroupedAndOptional() throws {
        let entries = [
            Self.entry(name: "Protein bar", mealType: .snack, calories: 210, protein: 20),
            Self.entry(name: "Unknown item", mealType: .unknown, calories: 90, protein: 2)
        ]
        let section = TodayMealsGroupingEngine.build(
            entries: entries,
            date: date(hour: 12),
            calendar: calendar
        )

        let snacks = try XCTUnwrap(group(.snack, in: section))
        XCTAssertTrue(snacks.isOptional)
        XCTAssertTrue(snacks.isLogged)
        XCTAssertEqual(snacks.entries.count, 2)
        XCTAssertEqual(snacks.totalCalories, 300)
        XCTAssertEqual(snacks.totalProtein, 22)
        XCTAssertFalse(snacks.isPastDueMissing)
    }

    func testMultipleEntriesSameMealTotals() throws {
        let entries = [
            Self.entry(name: "Chicken", mealType: .lunch, calories: 400, protein: 35, minuteOffset: 0),
            Self.entry(name: "Rice", mealType: .lunch, calories: 220, protein: 4, minuteOffset: 15)
        ]
        let section = TodayMealsGroupingEngine.build(
            entries: entries,
            date: date(hour: 13),
            calendar: calendar
        )

        let lunch = try XCTUnwrap(group(.lunch, in: section))
        XCTAssertTrue(lunch.isLogged)
        XCTAssertTrue(lunch.hasMultipleEntries)
        XCTAssertEqual(lunch.totalCalories, 620)
        XCTAssertEqual(lunch.totalProtein, 39)
        XCTAssertEqual(lunch.entries.map(\.name), ["Chicken", "Rice"])
    }

    func testNoMealsShowsActionableGroups() throws {
        let section = TodayMealsGroupingEngine.build(
            entries: [],
            date: date(hour: 10),
            calendar: calendar
        )

        XCTAssertTrue(section.isFullyEmpty)
        XCTAssertEqual(section.groups.count, 4)
        XCTAssertTrue(section.groups.allSatisfy { !$0.isLogged })

        let breakfast = try XCTUnwrap(group(.breakfast, in: section))
        XCTAssertFalse(breakfast.isPastDueMissing)

        let lunch = try XCTUnwrap(group(.lunch, in: section))
        XCTAssertFalse(lunch.isPastDueMissing)

        XCTAssertTrue(try XCTUnwrap(group(.snack, in: section)).isOptional)
    }

    func testGroupEntriesBucketsUnknownIntoSnacks() {
        let grouped = TodayMealsGroupingEngine.groupEntries([
            Self.entry(name: "Mystery", mealType: nil, calories: 100, protein: 5)
        ])
        XCTAssertEqual(grouped[.snack]?.count, 1)
        XCTAssertNil(grouped[.breakfast])
    }

    // MARK: - Helpers

    private func group(_ mealType: MealType, in section: TodayMealsSectionState) -> TodayMealGroupState? {
        section.groups.first { $0.mealType == mealType }
    }

    private static func entry(
        name: String,
        mealType: MealType?,
        calories: Int,
        protein: Double,
        minuteOffset: Int = 0
    ) -> FoodEntry {
        let base = calendarReferenceDate.addingTimeInterval(TimeInterval(minuteOffset * 60))
        return FoodEntry(
            id: UUID(),
            dailyLogId: UUID(),
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
            source: .manual,
            confidence: .high,
            imageUrl: nil,
            notes: nil,
            createdAt: base,
            updatedAt: base
        )
    }

    private static let calendarReferenceDate: Date = {
        Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 6, day: 28, hour: 8))!
    }()
}
