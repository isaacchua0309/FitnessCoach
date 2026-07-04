//
//  FormaModelContainer.swift
//  Fitness Coach
//
//  FitPilot AI — SwiftData container setup.
//

import Foundation
import SwiftData

enum FormaModelContainer {

    static let schema = Schema(versionedSchema: FormaSchemaV7.self)

    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        try makeContainer(inMemory: inMemory, storeURL: nil, markMigrationComplete: true)
    }

    static func makeContainer(
        inMemory: Bool,
        storeURL: URL?,
        markMigrationComplete: Bool = true
    ) throws -> ModelContainer {
        if !inMemory, storeURL == nil {
            try ensureApplicationSupportDirectoryExists()
        }

        let configuration: ModelConfiguration
        if let storeURL {
            configuration = ModelConfiguration(url: storeURL)
        } else {
            configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        }

        let container = try ModelContainer(
            for: schema,
            migrationPlan: FormaMigrationPlan.self,
            configurations: [configuration]
        )
        if markMigrationComplete {
            FormaSwiftDataMigrationGate.markCoachV2MigrationComplete()
        }
        return container
    }

    /// Opens a legacy schema at a dedicated store URL without marking Coach v2 migration complete.
    static func makeLegacyContainer<V: VersionedSchema>(
        _ versionedSchema: V.Type,
        storeURL: URL
    ) throws -> ModelContainer {
        let configuration = ModelConfiguration(url: storeURL)
        return try ModelContainer(
            for: Schema(versionedSchema: versionedSchema),
            configurations: [configuration]
        )
    }

    /// Migrates an on-disk legacy store to the current schema using `FormaMigrationPlan`.
    static func migrateContainer(at storeURL: URL) throws -> ModelContainer {
        let configuration = ModelConfiguration(url: storeURL)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: FormaMigrationPlan.self,
            configurations: [configuration]
        )
        FormaSwiftDataMigrationGate.markCoachV2MigrationComplete()
        return container
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
