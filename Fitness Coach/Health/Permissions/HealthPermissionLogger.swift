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
                "hasTrainingReadAccess": String(status.hasTrainingReadAccess),
                "allRequiredAvailable": String(status.allRequiredSignalsAvailable)
            ]
        )
    }

    static func permissionStateChanged(
        context: String,
        previousAvailableCount: Int,
        previousDeniedCount: Int,
        current: HealthPermissionStatus
    ) {
        event(
            "Health permission state changed",
            fields: [
                "context": context,
                "previousAvailableCount": String(previousAvailableCount),
                "previousDeniedCount": String(previousDeniedCount),
                "currentAvailableCount": String(current.availableSignals.count),
                "currentDeniedCount": String(current.deniedSignals.count),
                "allRequiredAvailable": String(current.allRequiredSignalsAvailable)
            ]
        )
    }

    // MARK: - Private

    private static let logger = Logger(subsystem: "FitPilot", category: "HealthPermission")

    private static func log(level: String, message: String, fields: [String: String]) {
        var metadata = fields
        metadata["level"] = level

        #if DEBUG
        print("[HealthPermission] \(HealthOSLogFormatting.message(message, fields: metadata))")
        #endif

        logger.log("\(HealthOSLogFormatting.message(message, fields: metadata), privacy: .public)")
    }
}
