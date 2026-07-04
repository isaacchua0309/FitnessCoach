//
//  FormaSwiftDataMigrationTestSupport.swift
//  Fitness CoachTests
//
//  Helpers for on-disk SwiftData migration tests.
//

import Foundation
import SwiftData
@testable import Fitness_Coach

enum FormaSwiftDataMigrationTestSupport {

    static let referenceDate: Date = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.date(from: DateComponents(year: 2026, month: 7, day: 3, hour: 12))!
    }()

    static func makeTemporaryStoreURL(label: String = UUID().uuidString) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("forma-migration-\(label).store")
    }

    static func removeStore(at url: URL) {
        let fileManager = FileManager.default
        let basePath = url.path
        for suffix in ["", "-wal", "-shm"] {
            let path = basePath + suffix
            try? fileManager.removeItem(atPath: path)
        }
    }

    @MainActor
    static func seedNutritionLogs(
        in context: ModelContext,
        referenceDate: Date = referenceDate
    ) throws -> (dailyLogID: UUID, foodID: UUID, waterID: UUID, weightID: UUID) {
        let dailyLogID = UUID()
        let foodID = UUID()
        let waterID = UUID()
        let weightID = UUID()

        let dailyLog = DailyLogEntity(
            id: dailyLogID,
            date: referenceDate,
            weightKg: 68.0,
            calorieTarget: 2_000,
            proteinTarget: 140,
            carbTarget: 180,
            fatTarget: 65,
            waterTargetMl: 2_500,
            expectedWeeklyWeightLossKg: 0.5,
            aggressivenessRawValue: "moderate",
            caloriesConsumed: 520,
            proteinConsumed: 35,
            carbsConsumed: 45,
            fatConsumed: 18,
            fiberConsumed: nil,
            sodiumConsumed: nil,
            waterConsumedMl: 500,
            steps: 6_000,
            workoutCaloriesBurned: 0,
            dailyReviewId: nil,
            createdAt: referenceDate,
            updatedAt: referenceDate
        )

        let food = FoodEntryEntity(
            id: foodID,
            dailyLogId: dailyLogID,
            mealTypeRawValue: "lunch",
            name: "Chicken rice",
            quantity: 1,
            unit: "plate",
            calories: 520,
            protein: 35,
            carbs: 45,
            fat: 18,
            fiber: nil,
            sodium: nil,
            sourceRawValue: "manual",
            confidenceRawValue: "high",
            imageUrl: nil,
            notes: nil,
            componentsJSON: nil,
            createdAt: referenceDate,
            updatedAt: referenceDate
        )
        food.dailyLog = dailyLog

        let water = WaterEntryEntity(
            id: waterID,
            dailyLogId: dailyLogID,
            amountMl: 500,
            createdAt: referenceDate
        )
        water.dailyLog = dailyLog

        let weight = WeightEntryEntity(
            id: weightID,
            date: referenceDate,
            weightKg: 68.0,
            note: nil,
            createdAt: referenceDate
        )

        context.insert(dailyLog)
        context.insert(food)
        context.insert(water)
        context.insert(weight)
        try context.save()

        return (dailyLogID, foodID, waterID, weightID)
    }

    @MainActor
    static func seedLegacyChatMessage(
        in context: ModelContext,
        referenceDate: Date = referenceDate
    ) throws -> UUID {
        let messageID = UUID()
        let entity = ChatMessageEntity(
            id: messageID,
            roleRawValue: "user",
            text: "legacy chat row",
            createdAt: referenceDate,
            relatedDailyLogId: nil,
            relatedEntryId: nil
        )
        context.insert(entity)
        try context.save()
        return messageID
    }

    @MainActor
    static func seedMalformedTimelineEvent(
        in context: ModelContext,
        referenceDate: Date = referenceDate
    ) throws -> UUID {
        let eventID = UUID()
        let entity = CoachTimelineEventEntity(
            id: eventID,
            userId: nil,
            eventTypeRaw: CoachTimelineEventType.foodLogged.rawValue,
            sourceRaw: CoachTimelineEventSource.coachUI.rawValue,
            statusRaw: CoachTimelineEventStatus.confirmed.rawValue,
            confidenceRaw: nil,
            sourceAttributionRaw: CoachTimelineEventSourceAttribution.userConfirmation.rawValue,
            utcCreatedAt: referenceDate,
            localCreatedAt: "2026-07-03T12:00:00+00:00",
            localDate: "2026-07-03",
            timezoneIdentifier: "UTC",
            summary: "Malformed payload row",
            payloadJSON: "{this is not valid json",
            linkedEntryId: nil,
            linkedMessageId: nil,
            supersedesEventId: nil,
            schemaVersion: 1,
            createdAt: referenceDate,
            updatedAt: referenceDate
        )
        context.insert(entity)
        try context.save()
        return eventID
    }

    static func fetchCount<T: PersistentModel>(
        _ type: T.Type,
        in container: ModelContainer
    ) throws -> Int {
        let context = ModelContext(container)
        return try context.fetch(FetchDescriptor<T>()).count
    }
}
