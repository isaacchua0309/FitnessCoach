//
//  ThemePersistenceDebugLogger.swift
//  Fitness Coach
//
//  Forma — DEBUG-only tracing for theme palette persistence and migration.
//

#if DEBUG
import Foundation
import OSLog

enum ThemePersistenceDebugLogger {

    nonisolated private static let logger = Logger(subsystem: "FitPilot", category: "ThemePersistence")

    nonisolated static func logMigration(
        from storedRawValue: String,
        to canonicalID: String,
        reason: ThemePalettePersistence.MigrationReason
    ) {
        logger.debug(
            "palette_migration from=\(storedRawValue, privacy: .public) to=\(canonicalID, privacy: .public) reason=\(reason.logLabel, privacy: .public)"
        )
    }

    nonisolated static func logLoaded(canonicalID: String) {
        logger.debug("palette_loaded id=\(canonicalID, privacy: .public)")
    }

    nonisolated static func logPersisted(canonicalID: String) {
        logger.debug("palette_persisted id=\(canonicalID, privacy: .public)")
    }
}
#endif
