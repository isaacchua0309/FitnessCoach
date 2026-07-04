//
//  CoachContextFoodMemoryBuilderTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class CoachContextFoodMemoryBuilderTests: XCTestCase {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }

    private var today: Date {
        calendar.startOfDay(for: calendar.date(from: DateComponents(year: 2026, month: 7, day: 3, hour: 12))!)
    }

    func testRecentMealsIncludeMacrosAndLocalDate() {
        let entry = makeEntry(
            name: "Chicken bowl",
            calories: 520,
            protein: 42,
            carbs: 38,
            fat: 16,
            createdAt: today.addingTimeInterval(3_600)
        )

        let meals = CoachContextFoodMemoryBuilder.makeRecentMeals(
            from: [entry],
            todayLocalDate: "2026-07-03",
            calendar: calendar
        )

        XCTAssertEqual(meals.count, 1)
        XCTAssertEqual(meals.first?.proteinGrams, 42)
        XCTAssertEqual(meals.first?.carbsGrams, 38)
        XCTAssertEqual(meals.first?.fatGrams, 16)
        XCTAssertEqual(meals.first?.localDate, "2026-07-03")
        XCTAssertEqual(meals.first?.source, FoodEntrySource.manual.rawValue)
    }

    func testCommonFoodsExcludeUncertainOneOff() {
        let uncertain = makeEntry(
            name: "Mystery snack",
            calories: 180,
            confidence: .low,
            source: .aiPhotoEstimate,
            createdAt: today
        )
        let repeated = [
            makeEntry(name: "Oatmeal", calories: 300, protein: 12, createdAt: today.addingTimeInterval(-100)),
            makeEntry(name: "Oatmeal", calories: 320, protein: 13, createdAt: today.addingTimeInterval(-200))
        ]

        let commonFoods = CoachContextFoodMemoryBuilder.makeCommonFoods(from: [uncertain] + repeated)

        XCTAssertEqual(commonFoods.count, 1)
        XCTAssertEqual(commonFoods.first?.name, "oatmeal")
        XCTAssertEqual(commonFoods.first?.frequency, 2)
        XCTAssertEqual(commonFoods.first?.typicalCalories, 310)
        XCTAssertEqual(commonFoods.first?.typicalProteinGrams, 12.5)
    }

    func testTodayMealsPrioritizedInRecentMeals() {
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        var entries: [FoodEntry] = []

        for index in 0..<6 {
            entries.append(
                makeEntry(
                    name: "Today meal \(index)",
                    calories: 200 + index,
                    createdAt: today.addingTimeInterval(Double(index * 60))
                )
            )
        }

        for index in 0..<6 {
            entries.append(
                makeEntry(
                    name: "Yesterday meal \(index)",
                    calories: 100 + index,
                    createdAt: yesterday.addingTimeInterval(Double(index * 60))
                )
            )
        }

        let meals = CoachContextFoodMemoryBuilder.makeRecentMeals(
            from: entries,
            todayLocalDate: "2026-07-03",
            calendar: calendar,
            limit: 8
        )

        XCTAssertEqual(meals.count, 8)
        XCTAssertTrue(meals.allSatisfy { $0.name.hasPrefix("Today meal") })
    }

    // MARK: Helpers

    private func makeEntry(
        name: String,
        calories: Int,
        protein: Double = 0,
        carbs: Double = 0,
        fat: Double = 0,
        confidence: ConfidenceLevel = .high,
        source: FoodEntrySource = .manual,
        createdAt: Date
    ) -> FoodEntry {
        FoodEntry(
            id: UUID(),
            dailyLogId: UUID(),
            mealType: .lunch,
            name: name,
            quantity: 1,
            unit: "serving",
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            fiber: nil,
            sodium: nil,
            source: source,
            confidence: confidence,
            imageUrl: nil,
            notes: nil,
            components: nil,
            createdAt: createdAt,
            updatedAt: createdAt
        )
    }
}
