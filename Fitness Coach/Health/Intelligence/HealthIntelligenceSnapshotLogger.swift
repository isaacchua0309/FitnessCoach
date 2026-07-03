//
//  HealthIntelligenceSnapshotLogger.swift
//  Fitness Coach
//
//  Forma — Production-safe debug logging for snapshot load/compose lifecycle.
//

import Foundation
import os

enum HealthIntelligenceSnapshotLogger {

    static func dayKey(for date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: calendar.startOfDay(for: date))
    }

    static func loadStarted(dayKey: String, mode: String, source: String) {
        event(
            "Snapshot load started",
            fields: [
                "dayKey": dayKey,
                "mode": mode,
                "source": source
            ]
        )
    }

    static func cacheHit(dayKey: String, mode: String, ageSeconds: Int) {
        event(
            "Snapshot cache hit",
            fields: [
                "dayKey": dayKey,
                "mode": mode,
                "cacheSource": "hit",
                "ageSeconds": String(ageSeconds)
            ]
        )
    }

    static func cacheMiss(dayKey: String, mode: String, reason: String) {
        event(
            "Snapshot cache miss",
            fields: [
                "dayKey": dayKey,
                "mode": mode,
                "cacheSource": "miss",
                "reason": reason
            ]
        )
    }

    static func coalescedInFlight(dayKey: String, mode: String) {
        event(
            "Snapshot load coalesced",
            fields: [
                "dayKey": dayKey,
                "mode": mode,
                "cacheSource": "coalesced"
            ]
        )
    }

    static func compositionStarted(dayKey: String, mode: String) {
        event(
            "Snapshot composition started",
            fields: [
                "dayKey": dayKey,
                "mode": mode
            ]
        )
    }

    static func compositionCompleted(dayKey: String, mode: String, durationMs: Int) {
        event(
            "Snapshot composition completed",
            fields: [
                "dayKey": dayKey,
                "mode": mode,
                "durationMs": String(durationMs)
            ]
        )
    }

    static func compositionFailed(dayKey: String, mode: String, reason: String) {
        warn(
            "Snapshot composition failed",
            fields: [
                "dayKey": dayKey,
                "mode": mode,
                "reason": reason
            ]
        )
    }

    static func invalidated(dayCount: Int, cancelledInFlightCount: Int) {
        event(
            "Intelligence snapshots invalidated",
            fields: [
                "dayCount": String(dayCount),
                "cancelledInFlightCount": String(cancelledInFlightCount)
            ]
        )
    }

    static func event(_ message: String, fields: [String: String] = [:]) {
        log(level: "info", message: message, fields: fields)
    }

    static func warn(_ message: String, fields: [String: String] = [:]) {
        log(level: "warn", message: message, fields: fields)
    }

    // MARK: - Private

    private static let logger = Logger(subsystem: "FitPilot", category: "HealthIntelligenceSnapshot")

    private static func log(level: String, message: String, fields: [String: String]) {
        var metadata = fields
        metadata["level"] = level

        #if DEBUG
        print("[HealthIntelligenceSnapshot] \(HealthOSLogFormatting.message(message, fields: metadata))")
        #endif

        logger.log("\(HealthOSLogFormatting.message(message, fields: metadata), privacy: .public)")
    }
}
