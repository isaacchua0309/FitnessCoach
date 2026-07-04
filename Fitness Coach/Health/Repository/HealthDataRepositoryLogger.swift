//
//  HealthDataRepositoryLogger.swift
//  Fitness Coach
//
//  Forma — Debug logging for HealthDataRepository (no sensitive values).
//

import Foundation
import os

enum HealthDataRepositoryLogger {

    static func event(_ message: String, fields: [String: String] = [:]) {
        log(level: "info", message: message, fields: fields)
    }

    static func warn(_ message: String, fields: [String: String] = [:]) {
        log(level: "warn", message: message, fields: fields)
    }

    static func fetchFailure(
        context: String,
        underlying: Error? = nil,
        fields: [String: String] = [:],
        level: String = "warn"
    ) {
        var merged = fields
        merged["context"] = context
        if let underlying {
            merged.merge(LogRedactor.safeErrorFields(from: underlying, includeDescription: false)) { _, new in new }
            #if DEBUG
            merged.merge(LogRedactor.safeErrorFields(from: underlying, includeDescription: true)) { _, new in new }
            #endif
        }
        log(level: level, message: "Health repository fetch degraded", fields: merged)
    }

    // MARK: - Private

    private static let logger = Logger(subsystem: "FitPilot", category: "HealthDataRepository")

    private static func log(level: String, message: String, fields: [String: String]) {
        var metadata = fields
        metadata["level"] = level

        #if DEBUG
        print("[HealthDataRepository] \(HealthOSLogFormatting.message(message, fields: metadata))")
        #endif

        logger.log("\(HealthOSLogFormatting.message(message, fields: metadata), privacy: .public)")
    }
}
