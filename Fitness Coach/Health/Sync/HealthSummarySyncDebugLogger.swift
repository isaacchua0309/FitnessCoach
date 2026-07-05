//
//  HealthSummarySyncDebugLogger.swift
//  Fitness Coach
//
//  Forma — Production-safe logging for local → remote Health Summary Sync handoff.
//  Logs payload counts and phases only; never raw HealthKit samples or secrets.
//

import Foundation
import os

enum HealthSummarySyncDebugLogger {

    static func localRefreshCompleted(
        phase: String,
        trigger: String,
        daysRequested: Int,
        daysCompleted: Int
    ) {
        log(
            message: "Local health refresh completed",
            fields: [
                "phase": phase,
                "trigger": trigger,
                "daysRequested": String(daysRequested),
                "daysCompleted": String(daysCompleted)
            ]
        )
    }

    static func remoteSyncStarted(
        trigger: String,
        syncWindowDays: Int
    ) {
        log(
            message: "Remote health summary sync started",
            fields: [
                "trigger": trigger,
                "syncWindowDays": String(syncWindowDays)
            ]
        )
    }

    static func remoteSyncAttempted(
        trigger: String,
        syncWindowDays: Int,
        dailyCount: Int,
        workoutCount: Int,
        recoveryCount: Int
    ) {
        log(
            message: "Remote health summary sync attempted",
            fields: [
                "trigger": trigger,
                "syncWindowDays": String(syncWindowDays),
                "dailyCount": String(dailyCount),
                "workoutCount": String(workoutCount),
                "recoveryCount": String(recoveryCount)
            ]
        )
    }

    static func remoteSyncSucceeded(
        trigger: String,
        dailyCount: Int,
        workoutCount: Int,
        recoveryCount: Int,
        metadataUploaded: Bool,
        durationMs: Int
    ) {
        log(
            message: "Remote health summary sync succeeded",
            fields: [
                "trigger": trigger,
                "dailyCount": String(dailyCount),
                "workoutCount": String(workoutCount),
                "recoveryCount": String(recoveryCount),
                "metadataUploaded": metadataUploaded ? "true" : "false",
                "durationMs": String(durationMs)
            ]
        )
    }

    static func remoteSyncFailed(
        trigger: String,
        phase: String,
        failedKinds: [HealthSummaryRemoteSyncPayloadKind],
        error: HealthSummarySyncError?,
        durationMs: Int
    ) {
        log(
            message: "Remote health summary sync failed",
            level: "warn",
            fields: [
                "trigger": trigger,
                "phase": phase,
                "failedKinds": failedKinds.map(\.rawValue).joined(separator: ","),
                "errorCategory": error.map { String(describing: $0) } ?? "none",
                "durationMs": String(durationMs)
            ]
        )
    }

    // MARK: - Private

    private static let logger = Logger(subsystem: "FitPilot", category: "HealthSummarySync")

    private static func log(message: String, level: String = "info", fields: [String: String]) {
        var metadata = fields
        metadata["level"] = level
        metadata["component"] = "HealthSummarySync"

        #if DEBUG
        print("[HealthSummarySync] \(HealthOSLogFormatting.message(message, fields: metadata))")
        #endif

        logger.log("\(HealthOSLogFormatting.message(message, fields: metadata), privacy: .public)")
    }
}
