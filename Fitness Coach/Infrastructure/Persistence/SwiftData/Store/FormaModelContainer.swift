//
//  FormaModelContainer.swift
//  Fitness Coach
//
//  FitPilot AI — SwiftData container setup.
//

import Foundation
import SwiftData

enum FormaModelContainer {

    /// Every persisted entity type must be listed here so SwiftData can build
    /// the full local schema.
    ///
    /// Dormant schema-only types (`WeeklyReviewEntity`, `ChatMessageEntity`,
    /// `DebugRecordEntity`) and legacy workout tables are documented in
    /// `Docs/PersistenceCleanupNotes.md`.
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
        if !inMemory {
            try ensureApplicationSupportDirectoryExists()
        }
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private static func ensureApplicationSupportDirectoryExists() throws {
        let fileManager = FileManager.default
        guard let url = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw CocoaError(.fileNoSuchFile)
        }
        try fileManager.createDirectory(
            at: url,
            withIntermediateDirectories: true
        )
    }
}
