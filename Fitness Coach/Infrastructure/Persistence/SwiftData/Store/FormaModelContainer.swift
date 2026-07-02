//
//  FormaModelContainer.swift
//  Fitness Coach
//
//  FitPilot AI — SwiftData container setup.
//

import Foundation
import SwiftData

enum FormaModelContainer {

    static let schema = Schema(versionedSchema: FormaSchemaV4.self)

    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        if !inMemory {
            try ensureApplicationSupportDirectoryExists()
        }
        let configuration = ModelConfiguration(
            isStoredInMemoryOnly: inMemory
        )
        return try ModelContainer(
            for: schema,
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
