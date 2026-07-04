//
//  CloudAccountDataMappersTests.swift
//  Fitness CoachTests
//
//  Forma — Account data cloud mapper tests (Phase 2).
//

import XCTest
@testable import Fitness_Coach

final class CloudAccountDataMappersTests: XCTestCase {

    private var calendar: Calendar!
    private var context: CloudAccountDataMappingContext!
    private let referenceDate = ProfileTestFixtures.referenceDate
    private let userId = "signed-in-user"

    override func setUp() {
        super.setUp()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        self.calendar = calendar
        context = CloudAccountDataMappingContext(
            userId: userId,
            calendar: calendar,
            timeZoneIdentifier: "UTC",
            deviceId: "test-device",
            appVersion: "1.0.0",
            now: referenceDate,
            mutationId: "mutation-1"
        )
    }

    func testDomainDailyLogRoundTripPreservesTotalsAndTargets() throws {
        let log = DailyLog(
            id: UUID(),
            date: referenceDate,
            weightKg: 70,
            targets: ProfileTestFixtures.sampleTargets,
            totals: MacroTotals(calories: 500, protein: 30, carbs: 40, fat: 15, fiber: 5, sodium: 200),
            waterConsumedMl: 600,
            steps: 5000,
            workoutCaloriesBurned: 180,
            dailyReviewId: nil,
            createdAt: referenceDate,
            updatedAt: referenceDate
        )

        let cloud = try CloudAccountDataMappers.cloudDocument(from: log, context: context)
        XCTAssertEqual(cloud.id, context.localDateString(for: referenceDate))
        XCTAssertEqual(cloud.userId, userId)

        let restored = try CloudAccountDataMappers.domainModel(from: cloud, calendar: calendar)
        XCTAssertEqual(restored.totals.calories, 500)
        XCTAssertEqual(restored.targets.calorieTarget, ProfileTestFixtures.sampleTargets.calorieTarget)
        XCTAssertEqual(restored.waterConsumedMl, 600)
        XCTAssertEqual(restored.workoutCaloriesBurned, 180)
    }

    func testDomainFoodEntryRoundTripPreservesComponents() throws {
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

        let cloud = try CloudAccountDataMappers.cloudDocument(
            from: entry,
            logDate: referenceDate,
            context: context
        )
        XCTAssertEqual(cloud.id, entry.id.uuidString)
        XCTAssertNotNil(cloud.componentsJSON)

        let restored = try CloudAccountDataMappers.domainModel(from: cloud)
        XCTAssertEqual(restored.name, "Combo bowl")
        XCTAssertEqual(restored.components?.count, 2)
    }

    func testDomainWaterAndWeightRoundTripsPreserveValues() throws {
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

        let cloudWater = try CloudAccountDataMappers.cloudDocument(
            from: water,
            logDate: referenceDate,
            context: context
        )
        let cloudWeight = try CloudAccountDataMappers.cloudDocument(from: weight, context: context)

        XCTAssertEqual(CloudAccountDataMappers.domainModel(from: cloudWater).amountMl, 350)
        XCTAssertEqual(
            try CloudAccountDataMappers.domainModel(from: cloudWeight, calendar: calendar).weightKg,
            68.4
        )
        XCTAssertEqual(cloudWater.updatedAt, water.createdAt)
    }

    func testDomainDailyReviewRoundTripPreservesTextFields() throws {
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

        let cloud = try CloudAccountDataMappers.cloudDocument(
            from: review,
            logDate: referenceDate,
            context: context
        )
        let restored = CloudAccountDataMappers.domainModel(from: cloud)

        XCTAssertEqual(restored.summaryText, "Solid day")
        XCTAssertEqual(restored.tomorrowRecommendation, "Repeat protein focus")
    }

    func testEntityMappingRejectsMissingOwnerUID() {
        let entity = DailyLogEntity(
            id: UUID(),
            ownerUID: nil,
            date: referenceDate,
            weightKg: nil,
            calorieTarget: 2000,
            proteinTarget: 140,
            carbTarget: 180,
            fatTarget: 65,
            waterTargetMl: 2500,
            expectedWeeklyWeightLossKg: nil,
            aggressivenessRawValue: CalorieAggressiveness.moderate.rawValue,
            caloriesConsumed: 0,
            proteinConsumed: 0,
            carbsConsumed: 0,
            fatConsumed: 0,
            fiberConsumed: nil,
            sodiumConsumed: nil,
            waterConsumedMl: 0,
            steps: nil,
            workoutCaloriesBurned: 0,
            dailyReviewId: nil,
            createdAt: referenceDate,
            updatedAt: referenceDate
        )

        XCTAssertThrowsError(
            try CloudAccountDataMappers.cloudDocument(from: entity, context: context)
        ) { error in
            XCTAssertEqual(
                error as? CloudAccountDataMappingError,
                .missingOwnerUID(entity: "DailyLogEntity", id: entity.id.uuidString)
            )
        }
    }

    func testEntityMappingRejectsOwnerMismatch() {
        let entity = FoodEntryEntity(
            id: UUID(),
            ownerUID: "other-user",
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
                .ownerMismatch(entity: "FoodEntryEntity", id: entity.id.uuidString)
            )
        }
    }

    func testEntityRoundTripSetsOwnerUIDFromCloudDocument() throws {
        let entity = FoodEntryEntity(
            id: UUID(),
            ownerUID: userId,
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

        let cloud = try CloudAccountDataMappers.cloudDocument(
            from: entity,
            logDate: referenceDate,
            context: context
        )
        XCTAssertEqual(cloud.id, entity.id.uuidString)
        XCTAssertNil(cloud.imageUrl)

        let restored = try CloudAccountDataMappers.entity(from: cloud, context: context)
        XCTAssertEqual(restored.ownerUID, userId)
        XCTAssertEqual(restored.name, "Salad")
        XCTAssertEqual(restored.calories, 400)
    }

    func testMapperRejectsEmptyUserId() {
        let invalidContext = CloudAccountDataMappingContext(
            userId: "   ",
            calendar: calendar,
            timeZoneIdentifier: "UTC"
        )
        let log = DailyLog(
            id: UUID(),
            date: referenceDate,
            weightKg: nil,
            targets: ProfileTestFixtures.sampleTargets,
            totals: MacroTotals(calories: 0, protein: 0, carbs: 0, fat: 0, fiber: nil, sodium: nil),
            waterConsumedMl: 0,
            steps: nil,
            workoutCaloriesBurned: 0,
            dailyReviewId: nil,
            createdAt: referenceDate,
            updatedAt: referenceDate
        )

        XCTAssertThrowsError(
            try CloudAccountDataMappers.cloudDocument(from: log, context: invalidContext)
        ) { error in
            XCTAssertEqual(
                error as? CloudAccountDataMappingError,
                .unsupportedPayload(entity: "mappingContext", id: "userId")
            )
        }
    }
}
