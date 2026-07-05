//
//  HealthSyncLogger.swift
//  Fitness Coach
//
//  Forma — Debug logging for health sync (no sensitive values).
//

import Foundation
import os

enum HealthSyncLogger {

    static func event(_ message: String, fields: [String: String] = [:]) {
        log(level: "info", message: message, fields: fields)
    }

    static func warn(_ message: String, fields: [String: String] = [:]) {
        log(level: "warn", message: message, fields: fields)
    }

    static func signalFailure(
        signal: HealthSignalKind,
        context: String,
        error: HealthSyncError
    ) {
        log(
            level: "warn",
            message: "Health sync signal degraded",
            fields: [
                "context": context,
                "signal": signal.rawValue,
                "errorCategory": String(describing: error)
            ]
        )
    }

    static func syncStarted(trigger: String, days: Int) {
        event(
            "Local sync started",
            fields: [
                "trigger": trigger,
                "daysRequested": String(days)
            ]
        )
    }

    static func syncCompleted(
        context: String,
        state: HealthSyncState,
        durationMs: Int
    ) {
        let failedSignals = state.signalResults
            .filter { !$0.succeeded }
            .map(\.signal.rawValue)
            .sorted()
            .joined(separator: ",")

        event(
            "Local sync completed",
            fields: syncStateFields(
                context: context,
                state: state,
                durationMs: durationMs,
                failedSignals: failedSignals
            )
        )
    }

    static func syncFailed(context: String, trigger: String, reason: String, durationMs: Int) {
        warn(
            "Local sync failed",
            fields: [
                "context": context,
                "trigger": trigger,
                "reason": reason,
                "durationMs": String(durationMs)
            ]
        )
    }

    static func logState(_ state: HealthSyncState, context: String) {
        let failedSignals = state.signalResults
            .filter { !$0.succeeded }
            .map(\.signal.rawValue)
            .sorted()
            .joined(separator: ",")

        event(
            "Sync state updated",
            fields: syncStateFields(
                context: context,
                state: state,
                durationMs: nil,
                failedSignals: failedSignals
            )
        )
    }

    // MARK: - Private

    private static let logger = Logger(subsystem: "FitPilot", category: "HealthSync")

    private static func syncStateFields(
        context: String,
        state: HealthSyncState,
        durationMs: Int?,
        failedSignals: String
    ) -> [String: String] {
        var fields: [String: String] = [
            "context": context,
            "phase": state.phase.rawValue,
            "trigger": state.trigger?.rawValue ?? "none",
            "daysCompleted": String(state.progress.daysCompleted),
            "daysRequested": String(state.progress.daysRequested),
            "failedSignals": failedSignals.isEmpty ? "none" : failedSignals
        ]
        if let durationMs {
            fields["durationMs"] = String(durationMs)
        }
        if let lastError = state.lastError {
            fields["lastErrorCategory"] = String(describing: lastError)
            #if DEBUG
            fields["lastError"] = lastError.localizedDescription
            #endif
        } else {
            fields["lastErrorCategory"] = "none"
        }
        return fields
    }

    private static func log(level: String, message: String, fields: [String: String]) {
        var metadata = fields
        metadata["level"] = level

        #if DEBUG
        print("[HealthSync] \(HealthOSLogFormatting.message(message, fields: metadata))")
        #endif

        logger.log("\(HealthOSLogFormatting.message(message, fields: metadata), privacy: .public)")
    }
}
