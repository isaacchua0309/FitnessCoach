//
//  FitPilotModelContainer.swift
//  Fitness Coach
//
//  FitPilot AI — SwiftData container setup.
//

import Foundation
import SwiftData

enum FitPilotModelContainer {

    /// Every persisted entity type must be listed here so SwiftData can build
    /// the full local schema.
    static let schema = Schema([
        UserProfileEntity.self,
        DailyLogEntity.self,
        FoodEntryEntity.self,
        WaterEntryEntity.self,
        WeightEntryEntity.self,
        WorkoutEntryEntity.self,
        ExerciseSetEntity.self,
        DailyReviewEntity.self,
        WeeklyReviewEntity.self,
        ChatMessageEntity.self,
        DebugRecordEntity.self
    ])

    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
