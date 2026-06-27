//
//  HealthTrainingDebugLogger.swift
//  Fitness Coach
//
//  Forma — DEBUG console tracing for Apple Health training integration.
//

import Foundation

#if DEBUG
import OSLog
#endif

enum HealthTrainingDebugLogger {

    /// Emits `[HealthTraining]` lines to the Xcode debug console (DEBUG builds only).
    nonisolated static func event(_ message: String, fields: [String: String] = [:]) {
        #if DEBUG
        guard isEnabled else { return }

        let fieldLine = fields
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")

        let line = fieldLine.isEmpty
            ? "[HealthTraining] \(message)"
            : "[HealthTraining] \(message) \(fieldLine)"

        print(line)
        logger.info("\(line, privacy: .public)")
        #endif
    }

    nonisolated static func warn(_ message: String, fields: [String: String] = [:]) {
        #if DEBUG
        guard isEnabled else { return }
        emit(level: "warn", message: message, fields: fields, osLog: { logger.warning("\($0, privacy: .public)") })
        #endif
    }

    nonisolated static func error(_ message: String, fields: [String: String] = [:], underlying: Error? = nil) {
        #if DEBUG
        guard isEnabled else { return }

        var merged = fields
        merged["level"] = "error"
        if let underlying {
            merged["error"] = String(describing: underlying)
            let nsError = underlying as NSError
            merged["errorDomain"] = nsError.domain
            merged["errorCode"] = String(nsError.code)
            if !nsError.localizedDescription.isEmpty {
                merged["errorDescription"] = nsError.localizedDescription
            }
        }
        emit(level: "error", message: message, fields: merged, osLog: { logger.error("\($0, privacy: .public)") })
        #endif
    }

    nonisolated private static func emit(
        level: String,
        message: String,
        fields: [String: String],
        osLog: (String) -> Void
    ) {
        #if DEBUG
        var merged = fields
        if !level.isEmpty {
            merged["level"] = level
        }
        let fieldLine = merged
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")
        let line = fieldLine.isEmpty
            ? "[HealthTraining] \(message)"
            : "[HealthTraining] \(message) \(fieldLine)"
        print(line)
        osLog(line)
        #endif
    }

    nonisolated static func logAuthorizationStatus(
        _ status: HealthTrainingAuthorizationStatus,
        context: String,
        fields: [String: String] = [:]
    ) {
        var merged = fields
        merged["context"] = context
        merged["authorizationStatus"] = status.debugLabel
        merged["integrationState"] = status.integrationState.debugLabel

        if case .sharingDenied = status {
            warn("Workout read access denied", fields: merged)
            event(
                "Denied troubleshooting: open Health app → Apps → Forma (Settings → Forma will not list Health)"
            )
        } else {
            event("Authorization status", fields: merged)
        }
    }

    nonisolated static func logIntegrationTransition(
        from previous: TrainingIntegrationState?,
        to next: TrainingIntegrationState,
        action: String,
        fields: [String: String] = [:]
    ) {
        var merged = fields
        merged["action"] = action
        if let previous {
            merged["previousState"] = previous.debugLabel
        }
        merged["nextState"] = next.debugLabel

        switch next {
        case .denied:
            warn("Integration state is access denied", fields: merged)
        case .failed(let message):
            error("Integration failed", fields: merged.merging(["failureMessage": message]) { _, new in new })
        case .unavailable:
            warn("Health data unavailable on this device", fields: merged)
        default:
            event("Integration state transition", fields: merged)
        }
    }

    #if DEBUG
    nonisolated private static let logger = Logger(subsystem: "FitPilot", category: "HealthTraining")

    /// Enabled in DEBUG unless `FITPILOT_HEALTH_TRACE=0`.
    nonisolated static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["FITPILOT_HEALTH_TRACE"] != "0"
    }
    #endif
}

extension HealthTrainingAuthorizationStatus {
    nonisolated var debugLabel: String {
        switch self {
        case .unavailable: return "unavailable"
        case .notDetermined: return "notDetermined"
        case .sharingDenied: return "sharingDenied"
        case .sharingAuthorized: return "sharingAuthorized"
        }
    }
}

extension TrainingIntegrationState {
    nonisolated var debugLabel: String {
        switch self {
        case .unavailable: return "unavailable"
        case .notConnected: return "notConnected"
        case .requestingPermission: return "requestingPermission"
        case .connected: return "connected"
        case .denied: return "denied"
        case .failed(let message): return "failed(\(message))"
        }
    }
}

#if canImport(HealthKit)
import HealthKit

extension HealthTrainingDebugLogger {
    nonisolated static func logHKAuthorizationStatus(
        _ status: HKAuthorizationStatus,
        context: String,
        typeName: String = "workout"
    ) {
        let mapped = mapHKStatus(status)
        let fields: [String: String] = [
            "healthKitStatus": hkStatusLabel(status),
            "sampleType": typeName
        ]
        logAuthorizationStatus(mapped, context: context, fields: fields)
    }

    nonisolated private static func mapHKStatus(_ status: HKAuthorizationStatus) -> HealthTrainingAuthorizationStatus {
        switch status {
        case .notDetermined: return .notDetermined
        case .sharingDenied: return .sharingDenied
        case .sharingAuthorized: return .sharingAuthorized
        @unknown default: return .notDetermined
        }
    }

    nonisolated private static func hkStatusLabel(_ status: HKAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "notDetermined"
        case .sharingDenied: return "sharingDenied"
        case .sharingAuthorized: return "sharingAuthorized"
        @unknown default: return "unknown(\(status.rawValue))"
        }
    }
}
#endif
