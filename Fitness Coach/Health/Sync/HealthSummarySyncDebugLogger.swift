//
//  HealthSummarySyncDebugLogger.swift
//  Fitness Coach
//
//  Forma — Debug-only logging for local → remote Health Summary Sync handoff.
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
        metadataUploaded: Bool
    ) {
        log(
            message: "Remote health summary sync succeeded",
            fields: [
                "trigger": trigger,
                "dailyCount": String(dailyCount),
                "workoutCount": String(workoutCount),
                "recoveryCount": String(recoveryCount),
                "metadataUploaded": metadataUploaded ? "true" : "false"
            ]
        )
    }

    static func remoteSyncFailed(
        trigger: String,
        phase: String,
        failedKinds: [HealthSummaryRemoteSyncPayloadKind],
        error: HealthSummarySyncError?
    ) {
        log(
            message: "Remote health summary sync failed",
            fields: [
                "trigger": trigger,
                "phase": phase,
                "failedKinds": failedKinds.map(\.rawValue).joined(separator: ","),
                "error": error?.localizedDescription ?? "none"
            ]
        )
    }

    // MARK: - Private

    #if DEBUG
    private static let logger = Logger(subsystem: "FitPilot", category: "HealthSummarySync")
    #endif

    private static func log(message: String, fields: [String: String]) {
        #if DEBUG
        var metadata = fields
        metadata["component"] = "HealthSummarySyncDebug"
        print("[HealthSummarySync] \(HealthOSLogFormatting.message(message, fields: metadata))")
        logger.log("\(HealthOSLogFormatting.message(message, fields: metadata), privacy: .public)")
        #else
        _ = message
        _ = fields
        #endif
    }
}
