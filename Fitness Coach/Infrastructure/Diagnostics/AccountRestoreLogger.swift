//
//  AccountRestoreLogger.swift
//  Fitness Coach
//
//  Forma — Privacy-safe OSLog tracing for account restore (Phase 4).
//
//  Logs aggregate counts and lifecycle metadata only. Never logs food names,
//  macros, weights, review text, profile names, raw Firestore payloads, or full UIDs.
//

import Foundation
import OSLog

struct AccountRestoreDiagnosticsSnapshot: Equatable, Sendable {
    let traceId: String
    let uidHash: String
    let reason: String
    let mode: String
    let status: String
    let startedAt: Date
    let endedAt: Date?
    let durationMs: Int?
    let profileRestored: Bool
    let dailyLogsRestored: Int
    let foodEntriesRestored: Int
    let waterEntriesRestored: Int
    let weightEntriesRestored: Int
    let dailyReviewsRestored: Int
    let skippedLocalNewer: Int
    let conflicts: Int
    let failed: Int
    let errorCategory: String?
    let wasOffline: Bool
    let wasPartial: Bool

    static func make(
        traceId: String,
        summary: AccountRestoreSummary,
        errorCategory: String? = nil
    ) -> AccountRestoreDiagnosticsSnapshot {
        let durationMs: Int?
        if let endedAt = summary.endedAt {
            durationMs = max(0, Int(endedAt.timeIntervalSince(summary.startedAt) * 1_000))
        } else {
            durationMs = nil
        }

        return AccountRestoreDiagnosticsSnapshot(
            traceId: traceId,
            uidHash: AccountSyncLogger.hashedUID(summary.uid),
            reason: summary.reason.rawValue,
            mode: summary.mode.rawValue,
            status: summary.status.rawValue,
            startedAt: summary.startedAt,
            endedAt: summary.endedAt,
            durationMs: durationMs,
            profileRestored: summary.profileRestored,
            dailyLogsRestored: summary.dailyLogsRestored,
            foodEntriesRestored: summary.foodEntriesRestored,
            waterEntriesRestored: summary.waterEntriesRestored,
            weightEntriesRestored: summary.weightEntriesRestored,
            dailyReviewsRestored: summary.dailyReviewsRestored,
            skippedLocalNewer: summary.skippedLocalNewer,
            conflicts: summary.conflicts,
            failed: summary.failed,
            errorCategory: errorCategory,
            wasOffline: summary.status == .offline,
            wasPartial: summary.isPartial || summary.status == .partial
        )
    }

    var safeFieldDictionary: [String: String] {
        var fields: [String: String] = [
            "traceId": traceId,
            "uidHash": uidHash,
            "reason": reason,
            "mode": mode,
            "status": status,
            "profileRestored": profileRestored ? "true" : "false",
            "dailyLogsRestored": String(dailyLogsRestored),
            "foodEntriesRestored": String(foodEntriesRestored),
            "waterEntriesRestored": String(waterEntriesRestored),
            "weightEntriesRestored": String(weightEntriesRestored),
            "dailyReviewsRestored": String(dailyReviewsRestored),
            "skippedLocalNewer": String(skippedLocalNewer),
            "conflicts": String(conflicts),
            "failed": String(failed),
            "wasOffline": wasOffline ? "true" : "false",
            "wasPartial": wasPartial ? "true" : "false"
        ]
        if let durationMs {
            fields["durationMs"] = String(durationMs)
        }
        if let errorCategory {
            fields["errorCategory"] = errorCategory
        }
        return fields
    }
}

enum AccountRestoreLogger {

    nonisolated private static let logger = Logger(subsystem: "FitPilot", category: "AccountRestore")

    nonisolated static func runStarted(
        traceId: String,
        reason: AccountRestoreReason,
        mode: AccountRestoreMode,
        uid: String
    ) {
        emit(
            levelName: "info",
            osLogType: .info,
            message: "restore_run_started",
            fields: [
                "traceId": traceId,
                "reason": reason.rawValue,
                "mode": mode.rawValue,
                "uidHash": AccountSyncLogger.hashedUID(uid)
            ]
        )
    }

    nonisolated static func runCompleted(_ snapshot: AccountRestoreDiagnosticsSnapshot) {
        emit(
            levelName: "info",
            osLogType: .info,
            message: "restore_run_completed",
            fields: snapshot.safeFieldDictionary
        )
    }

    nonisolated static func event(_ message: String, fields: [String: String] = [:]) {
        emit(levelName: "info", osLogType: .info, message: message, fields: fields)
    }

    nonisolated static func warn(_ message: String, fields: [String: String] = [:]) {
        emit(levelName: "warn", osLogType: .default, message: message, fields: fields)
    }

    nonisolated static func error(_ message: String, fields: [String: String] = [:], underlying: Error? = nil) {
        var merged = sanitizeFields(fields)
        if let underlying {
            merged["errorCategory"] = AccountSyncLogger.errorCategory(from: underlying)
        }
        emit(levelName: "error", osLogType: .error, message: message, fields: merged)
    }

    nonisolated static func errorCategory(from error: Error) -> String {
        AccountSyncLogger.errorCategory(from: error)
    }

    // MARK: - Private

    nonisolated private static func emit(
        levelName: String,
        osLogType: OSLogType,
        message: String,
        fields: [String: String]
    ) {
        #if DEBUG
        guard FormaAbTest.Diagnostics.accountRestoreTrace else { return }
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
            ? "[AccountRestore] \(message)"
            : "[AccountRestore] \(message) \(fieldLine)"

        logger.log(level: osLogType, "\(line, privacy: .public)")
    }

    nonisolated private static func sanitizeFields(_ fields: [String: String]) -> [String: String] {
        var result: [String: String] = [:]
        result.reserveCapacity(fields.count)
        for (key, value) in fields {
            let lowered = key.lowercased()
            if lowered == "uid" {
                result["uidHash"] = AccountSyncLogger.hashedUID(value)
                continue
            }
            if lowered.contains("uid"), lowered != "uidhash" {
                continue
            }
            if isSensitiveFieldKey(lowered) {
                continue
            }
            result[key] = sanitizeValue(value)
        }
        return result
    }

    nonisolated private static func sanitizeValue(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }
        if trimmed.count > 64 {
            return String(trimmed.prefix(64))
        }
        return trimmed
    }

    nonisolated private static func isSensitiveFieldKey(_ key: String) -> Bool {
        if allowedFieldKeys.contains(key) {
            return false
        }

        let blocked = [
            "name", "food", "calorie", "protein", "carb", "fat", "fiber", "sodium",
            "water", "weight", "review", "summary", "message", "note", "image", "base64",
            "coach", "text", "quantity", "amount", "document", "payload", "profile"
        ]
        return blocked.contains { key.contains($0) }
    }

    /// Aggregate restore metrics intentionally include words like "food" or "weight" in the key name.
    nonisolated private static let allowedFieldKeys: Set<String> = [
        "traceid",
        "uidhash",
        "reason",
        "mode",
        "status",
        "level",
        "durationms",
        "profilerestored",
        "dailylogsrestored",
        "foodentriesrestored",
        "waterentriesrestored",
        "weightentriesrestored",
        "dailyreviewsrestored",
        "skippedlocalnewer",
        "conflicts",
        "failed",
        "errorcategory",
        "wasoffline",
        "waspartial",
        "pendingcount"
    ]
}

extension AccountRemoteDataInspectionFailure {

    var analyticsCategory: String {
        switch self {
        case .offline: return "offline"
        case .permissionDenied: return "permission_denied"
        case .unauthenticated: return "unauthenticated"
        case .unavailable: return "unavailable"
        case .decodingFailed: return "decoding_failed"
        case .unknown: return "unknown"
        }
    }
}

#if DEBUG
enum AccountRestoreLoggerDebugSupport {

    static func redactedRestoreStateDescription(_ state: AccountRestoreStoredState) -> String {
        [
            "status=\(state.status.rawValue)",
            "lastStartedAt=\(state.lastStartedAt?.description ?? "nil")",
            "lastCompletedAt=\(state.lastCompletedAt?.description ?? "nil")",
            "lastSuccessfulBlockingRestoreAt=\(state.lastSuccessfulBlockingRestoreAt?.description ?? "nil")",
            "lastSuccessfulBackgroundBackfillAt=\(state.lastSuccessfulBackgroundBackfillAt?.description ?? "nil")",
            "restoredSchemaVersion=\(state.restoredSchemaVersion.map(String.init) ?? "nil")",
            "lastRestoreAppVersion=\(state.lastRestoreAppVersion ?? "nil")",
            "hasFailureMessage=\(state.lastFailureMessage != nil)"
        ].joined(separator: " ")
    }
}
#endif
