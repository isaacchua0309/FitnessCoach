//
//  CloudAccountDataMapperTests.swift
//  Fitness CoachTests
//
//  Forma — Account data cloud mapper tests (Phase 2).
//

import XCTest
@testable import Fitness_Coach

final class CloudAccountDataMapperTests: XCTestCase {

    private var calendar: Calendar!
    private var context: CloudAccountDataMappingContext!
    private let referenceDate = ProfileFixtures.referenceDate
    private let userA = "userA"
    private let userB = "userB"

    override func setUp() {
        super.setUp()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        self.calendar = calendar
        context = CloudAccountDataMappingContext(
            userId: userA,
            calendar: calendar,
            timeZoneIdentifier: "UTC",
            deviceId: "test-device",
            appVersion: "1.0.0",
            now: referenceDate,
            mutationId: "mutation-1"
        )
    }

    func testFoodEntryMapperRequiresOwnerUID() {
        let entity = FoodEntryEntity(
            id: UUID(),
            ownerUID: nil,
            dailyLogId: UUID(),
            mealTypeRawValue: MealType.lunch.rawValue,
            name: "Salad",
            quantity: 1,
            unit: "bowl",
            calories: 400,
            protein: 20,
            carbs: 30,
            fat: 12,
            fiber: nil,
            sodium: nil,
            sourceRawValue: FoodEntrySource.manual.rawValue,
            confidenceRawValue: ConfidenceLevel.high.rawValue,
            imageUrl: nil,
            notes: nil,
            createdAt: referenceDate,
            updatedAt: referenceDate
        )

        XCTAssertThrowsError(
            try CloudAccountDataMappers.cloudDocument(
                from: entity,
                logDate: referenceDate,
                context: context
            )
        ) { error in
            XCTAssertEqual(
                error as? CloudAccountDataMappingError,
                .missingOwnerUID(entity: "FoodEntryEntity", id: entity.id.uuidString)
            )
        }
    }

    func testFoodEntryMapperRejectsOwnerMismatch() {
        let entity = FoodEntryEntity(
            id: UUID(),
            ownerUID: userA,
            dailyLogId: UUID(),
            mealTypeRawValue: MealType.lunch.rawValue,
            name: "Salad",
            quantity: 1,
            unit: "bowl",
            calories: 400,
            protein: 20,
            carbs: 30,
            fat: 12,
            fiber: nil,
            sodium: nil,
            sourceRawValue: FoodEntrySource.manual.rawValue,
            confidenceRawValue: ConfidenceLevel.high.rawValue,
            imageUrl: nil,
            notes: nil,
            createdAt: referenceDate,
            updatedAt: referenceDate
        )
        let mismatchedContext = CloudAccountDataMappingContext(
            userId: userB,
            calendar: calendar,
            timeZoneIdentifier: "UTC"
        )

        XCTAssertThrowsError(
            try CloudAccountDataMappers.cloudDocument(
                from: entity,
                logDate: referenceDate,
                context: mismatchedContext
            )
        ) { error in
            XCTAssertEqual(
                error as? CloudAccountDataMappingError,
                .ownerMismatch(entity: "FoodEntryEntity", id: entity.id.uuidString)
            )
        }
    }

    func testFoodEntryMapperPreservesNutritionFields() throws {
        let entry = FoodEntry(
            id: UUID(),
            dailyLogId: UUID(),
            mealType: .lunch,
            name: "Chicken bowl",
            quantity: 1,
            unit: "bowl",
            calories: 520,
            protein: 42,
            carbs: 38,
            fat: 16,
            fiber: 5,
            sodium: 400,
            source: .manual,
            confidence: .high,
            imageUrl: nil,
            notes: nil,
            createdAt: referenceDate,
            updatedAt: referenceDate
        )

        let cloud = try CloudAccountDataMappers.cloudDocument(
            from: entry,
            logDate: referenceDate,
            context: context
        )

        XCTAssertEqual(cloud.name, "Chicken bowl")
        XCTAssertEqual(cloud.calories, 520)
        XCTAssertEqual(cloud.protein, 42)
        XCTAssertEqual(cloud.carbs, 38)
        XCTAssertEqual(cloud.fat, 16)
        XCTAssertEqual(cloud.source, FoodEntrySource.manual.rawValue)
        XCTAssertEqual(cloud.userId, userA)
    }

    func testWaterEntryMapperPreservesAmount() throws {
        let entry = WaterEntry(
            id: UUID(),
            dailyLogId: UUID(),
            amountMl: 475,
            createdAt: referenceDate
        )

        let cloud = try CloudAccountDataMappers.cloudDocument(
            from: entry,
            logDate: referenceDate,
            context: context
        )

        XCTAssertEqual(cloud.amountMl, 475)
        XCTAssertEqual(cloud.userId, userA)
        XCTAssertEqual(cloud.localDate, context.localDateString(for: referenceDate))
        XCTAssertEqual(cloud.createdAt, referenceDate)
    }

    func testWeightEntryMapperPreservesWeight() throws {
        let entry = WeightEntry(
            id: UUID(),
            date: referenceDate,
            weightKg: 67.8,
            note: "Morning",
            createdAt: referenceDate
        )

        let cloud = try CloudAccountDataMappers.cloudDocument(from: entry, context: context)

        XCTAssertEqual(cloud.weightKg, 67.8)
        XCTAssertEqual(cloud.userId, userA)
        XCTAssertEqual(cloud.localDate, context.localDateString(for: referenceDate))
    }

    func testDailyLogMapperPreservesTotalsAndTargets() throws {
        let log = DailyLog(
            id: UUID(),
            date: referenceDate,
            weightKg: 70,
            targets: UserTargets(
                calorieTarget: 2100,
                proteinTarget: 150,
                carbTarget: 190,
                fatTarget: 70,
                waterTargetMl: 2600,
                expectedWeeklyWeightLossKg: 0.5,
                aggressiveness: .moderate
            ),
            totals: MacroTotals(
                calories: 610,
                protein: 45,
                carbs: 52,
                fat: 20,
                fiber: 8,
                sodium: 500
            ),
            waterConsumedMl: 800,
            steps: 7000,
            workoutCaloriesBurned: 220,
            dailyReviewId: nil,
            createdAt: referenceDate,
            updatedAt: referenceDate
        )

        let cloud = try CloudAccountDataMappers.cloudDocument(from: log, context: context)

        XCTAssertEqual(cloud.caloriesConsumed, 610)
        XCTAssertEqual(cloud.proteinConsumed, 45)
        XCTAssertEqual(cloud.carbsConsumed, 52)
        XCTAssertEqual(cloud.fatConsumed, 20)
        XCTAssertEqual(cloud.calorieTarget, 2100)
        XCTAssertEqual(cloud.proteinTarget, 150)
        XCTAssertEqual(cloud.carbTarget, 190)
        XCTAssertEqual(cloud.fatTarget, 70)
        XCTAssertEqual(cloud.waterConsumedMl, 800)
    }

    func testDailyReviewMapperPreservesSummaryText() throws {
        let review = DailyReview(
            id: UUID(),
            dailyLogId: UUID(),
            summaryText: "Strong protein day",
            caloriesSummary: "On target",
            proteinSummary: "High",
            hydrationSummary: "Good",
            workoutSummary: "Lifted",
            weightSummary: "Stable",
            tomorrowRecommendation: "Keep protein high",
            createdAt: referenceDate
        )

        let cloud = try CloudAccountDataMappers.cloudDocument(
            from: review,
            logDate: referenceDate,
            context: context
        )

        XCTAssertEqual(cloud.summaryText, "Strong protein day")
        XCTAssertEqual(cloud.caloriesSummary, "On target")
        XCTAssertEqual(cloud.proteinSummary, "High")
        XCTAssertEqual(cloud.hydrationSummary, "Good")
        XCTAssertEqual(cloud.workoutSummary, "Lifted")
        XCTAssertEqual(cloud.weightSummary, "Stable")
        XCTAssertEqual(cloud.tomorrowRecommendation, "Keep protein high")
    }
}
