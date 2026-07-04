//
//  AccountSyncLogger.swift
//  Fitness Coach
//
//  Forma — Privacy-safe OSLog tracing for account data sync (Phase 3).
//

import Foundation
import OSLog

enum AccountSyncLogger {

    nonisolated private static let logger = Logger(subsystem: "FitPilot", category: "AccountSync")

    /// Short stable hash for correlating logs without logging full Firebase UIDs.
    nonisolated static func hashedUID(_ uid: String) -> String {
        LogRedactor.hashedUID(uid)
    }

    nonisolated static func errorCategory(from error: Error) -> String {
        if error is AccountDataRemoteStoreError { return "remote_store" }
        if error is CloudAccountDataMappingError { return "mapping" }
        if error is AccountSyncPayloadBuilderError { return "payload_builder" }
        if error is AccountSyncUploaderError { return "uploader" }
        if error is AccountSyncPullerError { return "puller" }
        let nsError = error as NSError
        if !nsError.domain.isEmpty {
            return "\(nsError.domain)#\(nsError.code)"
        }
        return "unknown"
    }

    nonisolated static func runStarted(
        traceId: String,
        reason: AccountSyncReason,
        uid: String
    ) {
        emit(
            levelName: "info",
            osLogType: .info,
            message: "sync_run_started",
            fields: [
                "traceId": traceId,
                "reason": reason.rawValue,
                "uidHash": hashedUID(uid)
            ]
        )
    }

    nonisolated static func runCompleted(_ snapshot: AccountSyncDiagnosticsSnapshot) {
        var fields: [String: String] = [
            "traceId": snapshot.traceId,
            "reason": snapshot.reason,
            "uidHash": snapshot.uidHash,
            "durationMs": String(snapshot.durationMs),
            "didSkip": snapshot.didSkip ? "true" : "false"
        ]
        if let skipReason = snapshot.skipReason {
            fields["skipReason"] = skipReason
        }
        if let upload = snapshot.upload {
            fields["uploadAttempted"] = String(upload.attempted)
            fields["uploadSucceeded"] = String(upload.succeeded)
            fields["uploadFailed"] = String(upload.failed)
            fields["uploadCancelled"] = String(upload.cancelled)
        }
        if let pull = snapshot.pull {
            fields["pullDailyLogsFetched"] = String(pull.dailyLogsFetched)
            fields["pullFoodEntriesFetched"] = String(pull.foodEntriesFetched)
            fields["pullInserted"] = String(pull.inserted)
            fields["pullUpdated"] = String(pull.updated)
            fields["pullSkippedLocalNewer"] = String(pull.skippedLocalNewer)
            fields["pullConflicts"] = String(pull.conflicts)
            fields["pullFailed"] = String(pull.failed)
        }
        emit(levelName: "info", osLogType: .info, message: "sync_run_completed", fields: fields)
    }

    nonisolated static func mutationProcessed(
        batchId: String,
        entityType: AccountSyncEntityType,
        operation: AccountSyncOperation,
        outcome: String,
        errorCategory: String? = nil
    ) {
        var fields: [String: String] = [
            "batchId": batchId,
            "entityType": entityType.rawValue,
            "operation": operation.rawValue,
            "outcome": outcome
        ]
        if let errorCategory {
            fields["errorCategory"] = errorCategory
        }
        emit(levelName: "info", osLogType: .info, message: "sync_mutation_processed", fields: fields)
    }

    nonisolated static func mutationFailed(
        batchId: String,
        entityType: AccountSyncEntityType,
        operation: AccountSyncOperation,
        error: Error
    ) {
        mutationProcessed(
            batchId: batchId,
            entityType: entityType,
            operation: operation,
            outcome: "failed",
            errorCategory: errorCategory(from: error)
        )
    }

    // MARK: - Private

    nonisolated private static func emit(
        levelName: String,
        osLogType: OSLogType,
        message: String,
        fields: [String: String]
    ) {
        #if DEBUG
        guard FormaAbTest.Diagnostics.accountSyncTrace else { return }
        #else
        return
        #endif

        var merged = LogRedactor.sanitizeLogFields(fields)
        merged["level"] = levelName

        let fieldLine = merged
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")

        let line = fieldLine.isEmpty
            ? "[AccountSync] \(message)"
            : "[AccountSync] \(message) \(fieldLine)"

        logger.log(level: osLogType, "\(line, privacy: .public)")
    }
}
