//
//  CloudAccountDataDocumentTests.swift
//  Fitness CoachTests
//
//  Forma — Account data cloud DTO tests (Phase 2).
//

import XCTest
@testable import Fitness_Coach

final class CloudAccountDataDocumentTests: XCTestCase {

    private let referenceDate = Date(timeIntervalSince1970: 1_750_000_000)
    private let userId = "userA"
    private let localDate = "2026-07-04"

    func testCloudFoodEntryDoesNotContainRawImageBase64() {
        let mirror = Mirror(reflecting: CloudFoodEntryDocument(
            id: "food1",
            userId: userId,
            dailyLogId: "daily-log-1",
            localDate: localDate,
            mealType: MealType.lunch.rawValue,
            name: "Salad",
            quantity: 1,
            unit: "bowl",
            calories: 400,
            protein: 20,
            carbs: 30,
            fat: 12,
            fiber: nil,
            sodium: nil,
            source: FoodEntrySource.manual.rawValue,
            confidence: ConfidenceLevel.high.rawValue,
            imageUrl: "https://example.com/meal.jpg",
            notes: nil,
            componentsJSON: nil,
            schemaVersion: AccountDataCloudSchema.currentSchemaVersion,
            createdAt: referenceDate,
            updatedAt: referenceDate,
            deletedAt: nil,
            deviceId: "test-device",
            mutationId: nil
        ))

        let propertyNames = mirror.children.compactMap(\.label)
        XCTAssertTrue(propertyNames.contains("imageUrl"))
        XCTAssertFalse(propertyNames.contains(where: { $0.lowercased().contains("base64") }))
        XCTAssertFalse(propertyNames.contains(where: { $0.lowercased().contains("imagebytes") }))
        XCTAssertFalse(propertyNames.contains(where: { $0.lowercased().contains("imagedata") }))
    }

    func testCloudDocumentsUseCurrentSchemaVersion() throws {
        let context = CloudAccountDataMappingContext(
            userId: userId,
            calendar: Calendar(identifier: .gregorian),
            timeZoneIdentifier: "UTC",
            now: referenceDate
        )

        let dailyLog = try CloudAccountDataMappers.cloudDocument(
            from: DailyLog(
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
            ),
            context: context
        )
        let food = try CloudAccountDataMappers.cloudDocument(
            from: FoodEntry(
                id: UUID(),
                dailyLogId: UUID(),
                mealType: .lunch,
                name: "Salad",
                quantity: 1,
                unit: "bowl",
                calories: 400,
                protein: 20,
                carbs: 30,
                fat: 12,
                fiber: nil,
                sodium: nil,
                source: .manual,
                confidence: .high,
                imageUrl: nil,
                notes: nil,
                createdAt: referenceDate,
                updatedAt: referenceDate
            ),
            logDate: referenceDate,
            context: context
        )
        let water = try CloudAccountDataMappers.cloudDocument(
            from: WaterEntry(
                id: UUID(),
                dailyLogId: UUID(),
                amountMl: 250,
                createdAt: referenceDate
            ),
            logDate: referenceDate,
            context: context
        )
        let weight = try CloudAccountDataMappers.cloudDocument(
            from: WeightEntry(
                id: UUID(),
                date: referenceDate,
                weightKg: 68.0,
                note: nil,
                createdAt: referenceDate
            ),
            context: context
        )
        let review = try CloudAccountDataMappers.cloudDocument(
            from: DailyReview(
                id: UUID(),
                dailyLogId: UUID(),
                summaryText: "Solid day",
                caloriesSummary: "On target",
                proteinSummary: "High",
                hydrationSummary: "Good",
                workoutSummary: nil,
                weightSummary: nil,
                tomorrowRecommendation: "Repeat",
                createdAt: referenceDate
            ),
            logDate: referenceDate,
            context: context
        )

        XCTAssertEqual(dailyLog.schemaVersion, AccountDataCloudSchema.currentSchemaVersion)
        XCTAssertEqual(food.schemaVersion, AccountDataCloudSchema.currentSchemaVersion)
        XCTAssertEqual(water.schemaVersion, AccountDataCloudSchema.currentSchemaVersion)
        XCTAssertEqual(weight.schemaVersion, AccountDataCloudSchema.currentSchemaVersion)
        XCTAssertEqual(review.schemaVersion, AccountDataCloudSchema.currentSchemaVersion)
        XCTAssertEqual(
            CloudAccountDataEnvelope.make(
                id: "entry-1",
                userId: userId,
                createdAt: referenceDate,
                updatedAt: referenceDate
            ).schemaVersion,
            AccountDataCloudSchema.currentSchemaVersion
        )
    }

    func testCloudDocumentsEncodeDecode() throws {
        let dailyLog = CloudDailyLogDocument(
            id: localDate,
            userId: userId,
            localDate: localDate,
            timezone: "UTC",
            calorieTarget: 2000,
            proteinTarget: 140,
            carbTarget: 180,
            fatTarget: 65,
            waterTargetMl: 2500,
            expectedWeeklyWeightLossKg: nil,
            aggressiveness: CalorieAggressiveness.moderate.rawValue,
            caloriesConsumed: 520,
            proteinConsumed: 35,
            carbsConsumed: 48,
            fatConsumed: 18,
            fiberConsumed: nil,
            sodiumConsumed: nil,
            waterConsumedMl: 750,
            steps: nil,
            workoutCaloriesBurned: 0,
            weightKg: nil,
            dailyReviewId: nil,
            schemaVersion: AccountDataCloudSchema.currentSchemaVersion,
            createdAt: referenceDate,
            updatedAt: referenceDate,
            deletedAt: nil,
            deviceId: "test-device",
            source: AccountDataCloudSchema.clientSource,
            mutationId: nil
        )
        let food = CloudFoodEntryDocument(
            id: "food1",
            userId: userId,
            dailyLogId: "daily-log-1",
            localDate: localDate,
            mealType: MealType.lunch.rawValue,
            name: "Salad",
            quantity: 1,
            unit: "bowl",
            calories: 400,
            protein: 20,
            carbs: 30,
            fat: 12,
            fiber: nil,
            sodium: nil,
            source: FoodEntrySource.manual.rawValue,
            confidence: ConfidenceLevel.high.rawValue,
            imageUrl: nil,
            notes: nil,
            componentsJSON: nil,
            schemaVersion: AccountDataCloudSchema.currentSchemaVersion,
            createdAt: referenceDate,
            updatedAt: referenceDate,
            deletedAt: nil,
            deviceId: "test-device",
            mutationId: nil
        )
        let water = CloudWaterEntryDocument(
            id: "water1",
            userId: userId,
            dailyLogId: "daily-log-1",
            localDate: localDate,
            amountMl: 350,
            schemaVersion: AccountDataCloudSchema.currentSchemaVersion,
            createdAt: referenceDate,
            updatedAt: referenceDate,
            deletedAt: nil,
            deviceId: "test-device",
            source: AccountDataCloudSchema.clientSource,
            mutationId: nil
        )
        let weight = CloudWeightEntryDocument(
            id: "weight1",
            userId: userId,
            localDate: localDate,
            weightKg: 68.4,
            note: nil,
            schemaVersion: AccountDataCloudSchema.currentSchemaVersion,
            createdAt: referenceDate,
            updatedAt: referenceDate,
            deletedAt: nil,
            deviceId: "test-device",
            source: AccountDataCloudSchema.clientSource,
            mutationId: nil
        )
        let review = CloudDailyReviewDocument(
            id: "review1",
            userId: userId,
            dailyLogId: "daily-log-1",
            localDate: localDate,
            summaryText: "Solid day",
            caloriesSummary: "On target",
            proteinSummary: "High",
            hydrationSummary: "Good",
            workoutSummary: nil,
            weightSummary: nil,
            tomorrowRecommendation: "Repeat",
            schemaVersion: AccountDataCloudSchema.currentSchemaVersion,
            createdAt: referenceDate,
            updatedAt: referenceDate,
            deletedAt: nil,
            deviceId: "test-device",
            source: AccountDataCloudSchema.clientSource,
            mutationId: nil
        )
        let metadata = CloudSyncMetadataDocument(
            userId: userId,
            schemaVersion: AccountDataCloudSchema.currentSchemaVersion,
            lastFullPullAt: nil,
            lastSuccessfulPushAt: referenceDate,
            lastSuccessfulPullAt: nil,
            lastKnownServerUpdatedAt: nil,
            lastMigrationAt: nil,
            lastDeviceId: "test-device",
            clientVersion: "1.0.0",
            updatedAt: referenceDate
        )

        let roundTrippedDailyLog: CloudDailyLogDocument = try AccountDataCloudTestSupport.roundTrip(dailyLog)
        let roundTrippedFood: CloudFoodEntryDocument = try AccountDataCloudTestSupport.roundTrip(food)
        let roundTrippedWater: CloudWaterEntryDocument = try AccountDataCloudTestSupport.roundTrip(water)
        let roundTrippedWeight: CloudWeightEntryDocument = try AccountDataCloudTestSupport.roundTrip(weight)
        let roundTrippedReview: CloudDailyReviewDocument = try AccountDataCloudTestSupport.roundTrip(review)
        let roundTrippedMetadata: CloudSyncMetadataDocument = try AccountDataCloudTestSupport.roundTrip(metadata)

        XCTAssertEqual(roundTrippedDailyLog, dailyLog)
        XCTAssertEqual(roundTrippedFood, food)
        XCTAssertEqual(roundTrippedWater, water)
        XCTAssertEqual(roundTrippedWeight, weight)
        XCTAssertEqual(roundTrippedReview, review)
        XCTAssertEqual(roundTrippedMetadata, metadata)
    }
}

enum AccountDataCloudTestSupport {

    static func roundTrip<T: Codable & Equatable>(_ value: T) throws -> T {
        let data = try JSONEncoder().encode(value)
        return try JSONDecoder().decode(T.self, from: data)
    }
}
