//
//  CloudNutritionDocumentsTests.swift
//  Fitness CoachTests
//
//  Forma — Cloud nutrition DTO JSON round-trip tests (Phase 2).
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
            updatedAt: referenceDate,
            createdAt: referenceDate,
            deletedAt: nil,
            mutationId: UUID().uuidString,
            deviceId: "test-device",
            source: AccountDataCloudSchema.clientSource
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
            updatedAt: referenceDate,
            createdAt: referenceDate,
            deletedAt: nil,
            mutationId: UUID().uuidString
        )

        let roundTripped = try NutritionCloudTestSupport.roundTrip(document)
        XCTAssertEqual(roundTripped, document)
    }

    func testSyncMetadataDocumentRoundTripsThroughJSON() throws {
        let document = CloudSyncMetadataDocument(
            userId: "signed-in-user",
            schemaVersion: 1,
            clientSchemaVersion: 1,
            lastPushedAt: referenceDate,
            lastPulledAt: nil,
            lastFullRestoreAt: nil,
            deviceId: "test-device",
            appVersion: "1.0.0",
            updatedAt: referenceDate
        )

        let roundTripped = try NutritionCloudTestSupport.roundTrip(document)
        XCTAssertEqual(roundTripped, document)
    }
}

enum NutritionCloudTestSupport {

    static func roundTrip<T: Codable & Equatable>(_ value: T) throws -> T {
        let data = try JSONEncoder().encode(value)
        return try JSONDecoder().decode(T.self, from: data)
    }
}
