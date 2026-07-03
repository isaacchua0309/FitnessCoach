//
//  HealthCacheStoreLogger.swift
//  Fitness Coach
//
//  Forma — Production-safe cache observability (counts and keys only).
//

import Foundation
import os

enum HealthCacheStoreLogger {

    static func cacheHit(kind: String, dayKey: String) {
        event(
            "Cache hit",
            fields: [
                "kind": kind,
                "dayKey": dayKey,
                "cacheSource": "hit"
            ]
        )
    }

    static func cacheMiss(kind: String, dayKey: String, reason: String = "not_cached") {
        event(
            "Cache miss",
            fields: [
                "kind": kind,
                "dayKey": dayKey,
                "cacheSource": "miss",
                "reason": reason
            ]
        )
    }

    static func snapshotsRemoved(dayCount: Int) {
        event(
            "Intelligence snapshots removed",
            fields: ["dayCount": String(dayCount)]
        )
    }

    static func event(_ message: String, fields: [String: String] = [:]) {
        var metadata = fields
        metadata["level"] = "info"

        #if DEBUG
        print("[HealthCache] \(HealthOSLogFormatting.message(message, fields: metadata))")
        #endif

        logger.log("\(HealthOSLogFormatting.message(message, fields: metadata), privacy: .public)")
    }

    private static let logger = Logger(subsystem: "FitPilot", category: "HealthCache")
}
