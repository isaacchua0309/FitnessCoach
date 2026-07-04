//
//  AccountRestoreLogger.swift
//  Fitness Coach
//
//  Forma — Privacy-safe OSLog tracing for account restore (Phase 4).
//

import Foundation
import OSLog

enum AccountRestoreLogger {

    nonisolated private static let logger = Logger(subsystem: "FitPilot", category: "AccountRestore")

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
