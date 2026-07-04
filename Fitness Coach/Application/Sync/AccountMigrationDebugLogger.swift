//
//  AccountMigrationDebugLogger.swift
//  Fitness Coach
//
//  Forma — Safe diagnostics for account migration (Phase 1).
//

import Foundation
import OSLog

enum AccountMigrationDebugLogger {

    nonisolated private static let logger = Logger(subsystem: "FitPilot", category: "AccountMigration")

    nonisolated static func backfillAllowed(uid: String, report: AccountMigrationBackfillReport) {
        log(
            level: .info,
            message: "account_migration_backfill_applied",
            fields: [
                "uid": ProfileBootstrapDebugLogger.redactedUID(uid),
                "rowsUpdated": String(report.totalRowsUpdated)
            ]
        )
    }

    nonisolated static func backfillRefused(uid: String, report: AccountMigrationBackfillReport) {
        log(
            level: .default,
            message: "account_migration_backfill_refused",
            fields: [
                "uid": ProfileBootstrapDebugLogger.redactedUID(uid),
                "reason": report.reason
            ]
        )
    }

    nonisolated static func backfillSkippedMissingUID() {
        log(
            level: .default,
            message: "account_migration_backfill_skipped",
            fields: ["reason": "missing_signed_in_uid"]
        )
    }

    nonisolated private static func log(
        level: OSLogType,
        message: String,
        fields: [String: String]
    ) {
        #if DEBUG
        guard FormaAbTest.Diagnostics.profileBootstrapTrace else { return }
        #endif

        let fieldLine = fields
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")

        let line = fieldLine.isEmpty
            ? "[AccountMigration] \(message)"
            : "[AccountMigration] \(message) \(fieldLine)"

        logger.log(level: level, "\(line, privacy: .public)")
    }
}
