//
//  AccountSyncLogger.swift
//  Fitness Coach
//
//  Forma — Privacy-safe OSLog tracing for account data sync (Phase 3).
//

import CryptoKit
import Foundation
import OSLog

enum AccountSyncLogger {

    nonisolated private static let logger = Logger(subsystem: "FitPilot", category: "AccountSync")

    /// Short stable hash for correlating logs without logging full Firebase UIDs.
    nonisolated static func hashedUID(_ uid: String) -> String {
        let digest = SHA256.hash(data: Data(uid.utf8))
        return digest.prefix(4).map { String(format: "%02x", $0) }.joined()
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

    nonisolated static func incrementalPullCompleted(
        traceId: String,
        summary: CrossDeviceSyncSummary
    ) {
        emit(
            levelName: "info",
            osLogType: .info,
            message: "incremental_pull_completed",
            fields: [
                "traceId": traceId,
                "mode": summary.mode.rawValue,
                "reason": summary.reason.rawValue,
                "status": summary.status.rawValue,
                "uidHash": hashedUID(summary.uid),
                "inserted": String(summary.inserted),
                "updated": String(summary.updated),
                "deleted": String(summary.deleted),
                "skippedLocalNewer": String(summary.skippedLocalNewer),
                "conflicts": String(summary.conflicts),
                "failed": String(summary.failed),
                "pulledProfile": summary.pulledProfile ? "true" : "false"
            ]
        )
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

        var merged = sanitizeFields(fields)
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

    nonisolated private static func sanitizeFields(_ fields: [String: String]) -> [String: String] {
        var result: [String: String] = [:]
        result.reserveCapacity(fields.count)
        for (key, value) in fields {
            let lowered = key.lowercased()
            if lowered.contains("uid"), lowered != "uidhash" {
                continue
            }
            if isSensitiveFieldKey(lowered) {
                continue
            }
            result[key] = value
        }
        return result
    }

    nonisolated private static func isSensitiveFieldKey(_ key: String) -> Bool {
        let blocked = [
            "name", "food", "calorie", "protein", "carb", "fat", "fiber", "sodium",
            "water", "weight", "review", "summary", "message", "note", "image", "base64",
            "coach", "text", "quantity", "amount"
        ]
        return blocked.contains { key.contains($0) }
    }
}
