//
//  CloudNutritionDocumentMappingTests.swift
//  Fitness CoachTests
//
//  Forma — Cloud nutrition DTO ↔ domain mapping tests (Phase 2).
//

import XCTest
@testable import Fitness_Coach

final class CloudNutritionDocumentMappingTests: XCTestCase {

    private var calendar: Calendar!
    private var context: CloudNutritionSyncMappingContext!
    private let referenceDate = ProfileFixtures.referenceDate

    override func setUp() {
        super.setUp()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        self.calendar = calendar
        context = CloudNutritionSyncMappingContext(
            userId: "signed-in-user",
            calendar: calendar,
            timeZoneIdentifier: "UTC",
            deviceId: "test-device",
            appVersion: "1.0.0",
            now: referenceDate,
            mutationId: "mutation-1"
        )
    }

    func testDailyLogMappingPreservesTotalsAndTargets() throws {
        let log = DailyLog(
            id: UUID(),
            date: referenceDate,
            weightKg: 70,
            targets: ProfileFixtures.sampleTargets,
            totals: MacroTotals(calories: 500, protein: 30, carbs: 40, fat: 15, fiber: 5, sodium: 200),
            waterConsumedMl: 600,
            steps: 5000,
            workoutCaloriesBurned: 180,
            dailyReviewId: nil,
            createdAt: referenceDate,
            updatedAt: referenceDate
        )

        let cloud = try CloudNutritionDocumentMapping.makeCloudDailyLogDocument(from: log, context: context)
        XCTAssertEqual(cloud.userId, "signed-in-user")
        XCTAssertEqual(cloud.localDate, context.localDateString(for: referenceDate))
        XCTAssertEqual(cloud.caloriesConsumed, 500)
        XCTAssertEqual(cloud.waterConsumedMl, 600)
        XCTAssertEqual(cloud.mutationId, "mutation-1")

        let restored = try CloudNutritionDocumentMapping.makeDailyLog(from: cloud, calendar: calendar)
        XCTAssertEqual(restored.totals.calories, 500)
        XCTAssertEqual(restored.targets.calorieTarget, ProfileFixtures.sampleTargets.calorieTarget)
        XCTAssertEqual(restored.waterConsumedMl, 600)
    }

    func testFoodEntryMappingPreservesMacrosAndComponents() throws {
        let entry = FoodEntry(
            id: UUID(),
            dailyLogId: UUID(),
            mealType: .lunch,
            name: "Combo bowl",
            quantity: 1,
            unit: "bowl",
            calories: 650,
            protein: 40,
            carbs: 55,
            fat: 22,
            fiber: 8,
            sodium: 500,
            source: .manual,
            confidence: .high,
            imageUrl: nil,
            notes: nil,
            components: [
                FoodComponent(name: "Rice", calories: 200, protein: 4, carbs: 45, fat: 1),
                FoodComponent(name: "Chicken", calories: 450, protein: 36, carbs: 10, fat: 21)
            ],
            createdAt: referenceDate,
            updatedAt: referenceDate
        )

        let cloud = try CloudNutritionDocumentMapping.makeCloudFoodEntryDocument(
            from: entry,
            logDate: referenceDate,
            context: context
        )
        XCTAssertEqual(cloud.userId, "signed-in-user")
        XCTAssertNotNil(cloud.componentsJSON)

        let restored = try CloudNutritionDocumentMapping.makeFoodEntry(from: cloud)
        XCTAssertEqual(restored.name, "Combo bowl")
        XCTAssertEqual(restored.calories, 650)
        XCTAssertEqual(restored.components?.count, 2)
    }

    func testWeightAndWaterMappingsPreserveValues() throws {
        let water = WaterEntry(
            id: UUID(),
            dailyLogId: UUID(),
            amountMl: 350,
            createdAt: referenceDate
        )
        let weight = WeightEntry(
            id: UUID(),
            date: referenceDate,
            weightKg: 68.4,
            note: "Morning",
            createdAt: referenceDate
        )

        let cloudWater = try CloudNutritionDocumentMapping.makeCloudWaterEntryDocument(
            from: water,
            logDate: referenceDate,
            context: context
        )
        let cloudWeight = try CloudNutritionDocumentMapping.makeCloudWeightEntryDocument(
            from: weight,
            context: context
        )

        XCTAssertEqual(
            CloudNutritionDocumentMapping.makeWaterEntry(from: cloudWater).amountMl,
            350
        )
        XCTAssertEqual(
            try CloudNutritionDocumentMapping.makeWeightEntry(from: cloudWeight, calendar: calendar).weightKg,
            68.4
        )
    }

    func testDailyReviewMappingPreservesTextFields() throws {
        let review = DailyReview(
            id: UUID(),
            dailyLogId: UUID(),
            summaryText: "Solid day",
            caloriesSummary: "On target",
            proteinSummary: "High",
            hydrationSummary: "Good",
            workoutSummary: "Walked",
            weightSummary: "Stable",
            tomorrowRecommendation: "Repeat protein focus",
            createdAt: referenceDate
        )

        let cloud = try CloudNutritionDocumentMapping.makeCloudDailyReviewDocument(
            from: review,
            logDate: referenceDate,
            context: context
        )
        let restored = CloudNutritionDocumentMapping.makeDailyReview(from: cloud)

        XCTAssertEqual(restored.summaryText, "Solid day")
        XCTAssertEqual(restored.tomorrowRecommendation, "Repeat protein focus")
    }
}
