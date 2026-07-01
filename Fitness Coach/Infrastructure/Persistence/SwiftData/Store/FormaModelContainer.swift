//
//  FormaModelContainer.swift
//  Fitness Coach
//
//  FitPilot AI — SwiftData container setup.
//

import Foundation
import SwiftData

enum FormaModelContainer {

    /// Active schema (v2). Dormant v1 tables (`WeeklyReviewEntity`, `ChatMessageEntity`,
    /// `DebugRecordEntity`) are removed via `FormaMigrationPlan`. Legacy workout tables
    /// (`WorkoutEntryEntity`, `ExerciseSetEntity`) remain for on-disk history but are no
    /// longer read — training activity comes from Apple Health. See
    /// `Docs/PersistenceCleanupNotes.md`.
    static let schema = Schema(versionedSchema: FormaSchemaV2.self)

    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        if !inMemory {
            try ensureApplicationSupportDirectoryExists()
        }
        let configuration = ModelConfiguration(
            isStoredInMemoryOnly: inMemory
        )
        return try ModelContainer(
            for: FormaSchemaV2.self,
            migrationPlan: FormaMigrationPlan.self,
            configurations: [configuration]
        )
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
