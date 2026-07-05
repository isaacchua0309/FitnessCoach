//
//  CrossDeviceSyncLogger.swift
//  Fitness Coach
//
//  Forma — Privacy-safe OSLog tracing for Phase 5 cross-device sync.
//
//  Logs counts, statuses, and hashed identifiers only. Never logs food names,
//  macros, weights, review text, profile fields, raw payloads, or full UIDs.
//

import Foundation
import OSLog

enum CrossDeviceSyncLogger {

    nonisolated private static let logger = Logger(subsystem: "FitPilot", category: "CrossDeviceSync")

    // MARK: - Cross-device sync run

    nonisolated static func syncStarted(
        traceId: String,
        mode: CrossDeviceSyncMode,
        reason: CrossDeviceSyncReason,
        uid: String
    ) {
        emit(
            levelName: "info",
            osLogType: .info,
            message: "cross_device_sync_started",
            fields: [
                "traceId": traceId,
                "uidHash": AccountSyncLogger.hashedUID(uid),
                "mode": mode.rawValue,
                "reason": reason.rawValue
            ]
        )
    }

    nonisolated static func syncCompleted(
        traceId: String,
        summary: CrossDeviceSyncSummary,
        errorCategory: String? = nil
    ) {
        emit(
            levelName: "info",
            osLogType: .info,
            message: "cross_device_sync_completed",
            fields: completionFields(
                traceId: traceId,
                summary: summary,
                errorCategory: errorCategory
            )
        )
    }

    nonisolated static func incrementalPullCompleted(
        traceId: String,
        summary: CrossDeviceSyncSummary,
        errorCategory: String? = nil
    ) {
        emit(
            levelName: "info",
            osLogType: .info,
            message: "incremental_pull_completed",
            fields: completionFields(
                traceId: traceId,
                summary: summary,
                errorCategory: errorCategory
            )
        )
    }

    // MARK: - Realtime listener

    nonisolated static func listenerStarted(uid: String, listenerCount: Int) {
        emit(
            levelName: "info",
            osLogType: .info,
            message: "realtime_listener_started",
            fields: [
                "uidHash": AccountSyncLogger.hashedUID(uid),
                "listenerStarted": "true",
                "listenerCount": String(listenerCount)
            ]
        )
    }

    nonisolated static func listenerStopped(uid: String, reason: String) {
        emit(
            levelName: "info",
            osLogType: .info,
            message: "realtime_listener_stopped",
            fields: [
                "uidHash": AccountSyncLogger.hashedUID(uid),
                "listenerStopped": "true",
                "stopReason": reason
            ]
        )
    }

    nonisolated static func changeHintEmitted(uid: String, source: String) {
        emit(
            levelName: "info",
            osLogType: .info,
            message: "realtime_change_hint_emitted",
            fields: [
                "uidHash": AccountSyncLogger.hashedUID(uid),
                "source": source
            ]
        )
    }

    // MARK: - Merge conflicts

    nonisolated static func mergeConflictDetected(
        traceId: String?,
        entityType: AccountSyncEntityType,
        cloudIdSuffix: String,
        reason: AccountSyncMergeConflictReason
    ) {
        var fields: [String: String] = [
            "entityType": entityType.rawValue,
            "cloudIdSuffix": cloudIdSuffix,
            "conflictReason": reason.rawValue
        ]
        if let traceId {
            fields["traceId"] = traceId
        }
        emit(
            levelName: "info",
            osLogType: .info,
            message: "merge_conflict_detected",
            fields: fields
        )
    }

    nonisolated static func profileMergeConflictDetected(traceId: String?, uid: String) {
        var fields: [String: String] = [
            "uidHash": AccountSyncLogger.hashedUID(uid)
        ]
        if let traceId {
            fields["traceId"] = traceId
        }
        emit(
            levelName: "info",
            osLogType: .info,
            message: "profile_merge_conflict_detected",
            fields: fields
        )
    }

    // MARK: - Field builders

    nonisolated static func completionFields(
        traceId: String,
        summary: CrossDeviceSyncSummary,
        errorCategory: String? = nil
    ) -> [String: String] {
        var fields: [String: String] = [
            "traceId": traceId,
            "uidHash": AccountSyncLogger.hashedUID(summary.uid),
            "mode": summary.mode.rawValue,
            "reason": summary.reason.rawValue,
            "status": summary.status.rawValue,
            "uploadedMutations": String(summary.uploadedMutations),
            "pulledDailyLogs": String(summary.pulledDailyLogs),
            "pulledFoodEntries": String(summary.pulledFoodEntries),
            "pulledWaterEntries": String(summary.pulledWaterEntries),
            "pulledWeightEntries": String(summary.pulledWeightEntries),
            "pulledDailyReviews": String(summary.pulledDailyReviews),
            "pulledProfile": summary.pulledProfile ? "true" : "false",
            "inserted": String(summary.inserted),
            "updated": String(summary.updated),
            "deleted": String(summary.deleted),
            "conflicts": String(summary.conflicts),
            "failed": String(summary.failed),
            "offline": (summary.status == .offline) ? "true" : "false"
        ]

        if let endedAt = summary.endedAt {
            let durationMs = max(0, Int(endedAt.timeIntervalSince(summary.startedAt) * 1_000))
            fields["durationMs"] = String(durationMs)
        }

        if let errorCategory {
            fields["errorCategory"] = errorCategory
        }

        return fields
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
            ? "[CrossDeviceSync] \(message)"
            : "[CrossDeviceSync] \(message) \(fieldLine)"

        logger.log(level: osLogType, "\(line, privacy: .public)")
    }
}
