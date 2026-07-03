//
//  HealthPermissionLogger.swift
//  Fitness Coach
//
//  Forma — Debug logging for Health Intelligence permissions (no sensitive values).
//

import Foundation
import os

enum HealthPermissionLogger {

    static func event(_ message: String, fields: [String: String] = [:]) {
        log(level: "info", message: message, fields: fields)
    }

    static func warn(_ message: String, fields: [String: String] = [:]) {
        log(level: "warn", message: message, fields: fields)
    }

    static func authorizationFailure(
        context: String,
        signal: HealthSignalKind? = nil,
        underlying: Error? = nil
    ) {
        var fields: [String: String] = ["context": context]
        if let signal {
            fields["signal"] = signal.rawValue
        }
        if let underlying {
            fields["errorDomain"] = (underlying as NSError).domain
            fields["errorCode"] = String((underlying as NSError).code)
            let description = underlying.localizedDescription
            if !description.isEmpty {
                fields["errorDescription"] = description
            }
        }
        log(level: "error", message: "Health permission failure", fields: fields)
    }

    static func logResolvedStatus(_ status: HealthPermissionStatus, context: String) {
        let available = status.availableSignals.map(\.rawValue).sorted().joined(separator: ",")
        let denied = status.deniedSignals.map(\.rawValue).sorted().joined(separator: ",")
        event(
            "Resolved health permission status",
            fields: [
                "context": context,
                "healthDataAvailable": String(status.isHealthDataAvailable),
                "availableCount": String(status.availableSignals.count),
                "deniedCount": String(status.deniedSignals.count),
                "availableSignals": available.isEmpty ? "none" : available,
                "deniedSignals": denied.isEmpty ? "none" : denied,
                "hasTrainingReadAccess": String(status.hasTrainingReadAccess)
            ]
        )
    }

    // MARK: - Private

    private static let logger = Logger(subsystem: "FitPilot", category: "HealthPermission")

    private static func log(level: String, message: String, fields: [String: String]) {
        #if DEBUG
        let fieldLine = fields
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")
        let line = fieldLine.isEmpty
            ? "[HealthPermission] \(message)"
            : "[HealthPermission] \(message) \(fieldLine)"
        print(line)
        #endif

        var metadata: [String: String] = fields
        metadata["level"] = level
        logger.log("\(message, privacy: .public)")
    }
}
