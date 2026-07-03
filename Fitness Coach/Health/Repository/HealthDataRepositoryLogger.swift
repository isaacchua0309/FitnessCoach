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
        fields: [String: String] = [:]
    ) {
        var merged = fields
        merged["context"] = context
        if let underlying {
            merged["errorDomain"] = (underlying as NSError).domain
            merged["errorCode"] = String((underlying as NSError).code)
            let description = underlying.localizedDescription
            if !description.isEmpty {
                merged["errorDescription"] = description
            }
        }
        log(level: "warn", message: "Health repository fetch degraded", fields: merged)
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
