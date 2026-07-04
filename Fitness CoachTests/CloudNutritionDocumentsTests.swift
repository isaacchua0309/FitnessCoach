//
//  CloudNutritionDocumentsTests.swift
//  Fitness CoachTests
//
//  Forma — Account data cloud DTO JSON round-trip tests (Phase 2).
//

import XCTest
@testable import Fitness_Coach

final class CloudNutritionDocumentsTests: XCTestCase {

    private let referenceDate = Date(timeIntervalSince1970: 1_750_000_000)

    func testDailyLogDocumentRoundTripsThroughJSON() throws {
        let document = CloudDailyLogDocument(
            id: "2026-07-03",
            userId: "signed-in-user",
            localDate: "2026-07-03",
            timezone: "America/Los_Angeles",
            calorieTarget: 2000,
            proteinTarget: 140,
            carbTarget: 180,
            fatTarget: 65,
            waterTargetMl: 2500,
            expectedWeeklyWeightLossKg: 0.5,
            aggressiveness: CalorieAggressiveness.moderate.rawValue,
            caloriesConsumed: 520,
            proteinConsumed: 35,
            carbsConsumed: 48,
            fatConsumed: 18,
            fiberConsumed: 6,
            sodiumConsumed: 400,
            waterConsumedMl: 750,
            steps: 8000,
            workoutCaloriesBurned: 250,
            weightKg: 68.2,
            dailyReviewId: nil,
            schemaVersion: AccountDataCloudSchema.currentSchemaVersion,
            createdAt: referenceDate,
            updatedAt: referenceDate,
            deletedAt: nil,
            deviceId: "test-device",
            source: AccountDataCloudSchema.clientSource,
            mutationId: UUID().uuidString
        )

        let roundTripped = try NutritionCloudTestSupport.roundTrip(document)
        XCTAssertEqual(roundTripped, document)
    }

    func testFoodEntryDocumentRoundTripsThroughJSON() throws {
        let document = CloudFoodEntryDocument(
            id: UUID().uuidString,
            userId: "signed-in-user",
            dailyLogId: UUID().uuidString,
            localDate: "2026-07-03",
            mealType: MealType.lunch.rawValue,
            name: "Chicken salad",
            quantity: 1,
            unit: "bowl",
            calories: 450,
            protein: 35,
            carbs: 20,
            fat: 18,
            fiber: 4,
            sodium: 300,
            source: FoodEntrySource.manual.rawValue,
            confidence: ConfidenceLevel.high.rawValue,
            imageUrl: nil,
            notes: "No dressing",
            componentsJSON: nil,
            schemaVersion: AccountDataCloudSchema.currentSchemaVersion,
            createdAt: referenceDate,
            updatedAt: referenceDate,
            deletedAt: nil,
            deviceId: "test-device",
            mutationId: UUID().uuidString
        )

        let roundTripped = try NutritionCloudTestSupport.roundTrip(document)
        XCTAssertEqual(roundTripped, document)
    }

    func testWaterEntryDocumentRoundTripsThroughJSON() throws {
        let document = CloudWaterEntryDocument(
            id: UUID().uuidString,
            userId: "signed-in-user",
            dailyLogId: UUID().uuidString,
            localDate: "2026-07-03",
            amountMl: 350,
            schemaVersion: AccountDataCloudSchema.currentSchemaVersion,
            createdAt: referenceDate,
            updatedAt: referenceDate,
            deletedAt: nil,
            deviceId: "test-device",
            source: AccountDataCloudSchema.clientSource,
            mutationId: UUID().uuidString
        )

        let roundTripped = try NutritionCloudTestSupport.roundTrip(document)
        XCTAssertEqual(roundTripped, document)
    }

    func testWeightEntryDocumentRoundTripsThroughJSON() throws {
        let document = CloudWeightEntryDocument(
            id: UUID().uuidString,
            userId: "signed-in-user",
            localDate: "2026-07-03",
            weightKg: 68.4,
            note: "Morning",
            schemaVersion: AccountDataCloudSchema.currentSchemaVersion,
            createdAt: referenceDate,
            updatedAt: referenceDate,
            deletedAt: nil,
            deviceId: "test-device",
            source: AccountDataCloudSchema.clientSource,
            mutationId: nil
        )

        let roundTripped = try NutritionCloudTestSupport.roundTrip(document)
        XCTAssertEqual(roundTripped, document)
    }

    func testDailyReviewDocumentRoundTripsThroughJSON() throws {
        let document = CloudDailyReviewDocument(
            id: UUID().uuidString,
            userId: "signed-in-user",
            dailyLogId: UUID().uuidString,
            localDate: "2026-07-03",
            summaryText: "Solid day",
            caloriesSummary: "On target",
            proteinSummary: "High",
            hydrationSummary: "Good",
            workoutSummary: "Walked",
            weightSummary: "Stable",
            tomorrowRecommendation: "Repeat protein focus",
            schemaVersion: AccountDataCloudSchema.currentSchemaVersion,
            createdAt: referenceDate,
            updatedAt: referenceDate,
            deletedAt: nil,
            deviceId: "test-device",
            source: AccountDataCloudSchema.clientSource,
            mutationId: nil
        )

        let roundTripped = try NutritionCloudTestSupport.roundTrip(document)
        XCTAssertEqual(roundTripped, document)
    }

    func testSyncMetadataDocumentRoundTripsThroughJSON() throws {
        let document = CloudSyncMetadataDocument(
            userId: "signed-in-user",
            schemaVersion: AccountDataCloudSchema.currentSchemaVersion,
            lastFullPullAt: referenceDate,
            lastSuccessfulPushAt: referenceDate,
            lastSuccessfulPullAt: nil,
            lastKnownServerUpdatedAt: referenceDate,
            lastMigrationAt: nil,
            lastDeviceId: "test-device",
            clientVersion: "1.0.0",
            updatedAt: referenceDate
        )

        let roundTripped = try NutritionCloudTestSupport.roundTrip(document)
        XCTAssertEqual(roundTripped, document)
    }

    func testAccountDataEnvelopeFactoryUsesCurrentSchemaVersion() {
        let envelope = CloudAccountDataEnvelope.make(
            id: "entry-1",
            userId: "signed-in-user",
            createdAt: referenceDate,
            updatedAt: referenceDate,
            deviceId: "test-device"
        )

        XCTAssertEqual(envelope.schemaVersion, AccountDataCloudSchema.currentSchemaVersion)
        XCTAssertEqual(envelope.source, AccountDataCloudSchema.clientSource)
    }
}

enum NutritionCloudTestSupport {

    static func roundTrip<T: Codable & Equatable>(_ value: T) throws -> T {
        let data = try JSONEncoder().encode(value)
        return try JSONDecoder().decode(T.self, from: data)
    }
}
