//
//  ProfileBootstrapDebugLogger.swift
//  Fitness Coach
//
//  Forma — DEBUG console tracing for local/cloud profile bootstrap.
//

import Foundation

#if DEBUG
import OSLog
#endif

enum ProfileBootstrapDebugLogger {

    /// Emits `[ProfileBootstrap]` lines to the unified log (DEBUG builds only).
    nonisolated static func event(_ message: String, fields: [String: String] = [:]) {
        #if DEBUG
        guard isEnabled else { return }
        emit(level: "info", message: message, fields: fields, osLog: { logger.info("\($0, privacy: .public)") })
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
        if let underlying {
            merged["error"] = String(describing: underlying)
            let nsError = underlying as NSError
            if !nsError.domain.isEmpty {
                merged["errorDomain"] = nsError.domain
                merged["errorCode"] = String(nsError.code)
            }
            if !nsError.localizedDescription.isEmpty {
                merged["errorDescription"] = nsError.localizedDescription
            }
        }
        emit(level: "error", message: message, fields: merged, osLog: { logger.error("\($0, privacy: .public)") })
        #endif
    }

    #if DEBUG
    nonisolated private static let logger = Logger(subsystem: "FitPilot", category: "ProfileBootstrap")

    /// Enabled in DEBUG unless `FITPILOT_PROFILE_BOOTSTRAP_TRACE=0`.
    nonisolated static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["FITPILOT_PROFILE_BOOTSTRAP_TRACE"] != "0"
    }

    nonisolated private static func emit(
        level: String,
        message: String,
        fields: [String: String],
        osLog: (String) -> Void
    ) {
        var merged = fields
        if !level.isEmpty {
            merged["level"] = level
        }
        let fieldLine = merged
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")
        let line = fieldLine.isEmpty
            ? "[ProfileBootstrap] \(message)"
            : "[ProfileBootstrap] \(message) \(fieldLine)"
        osLog(line)
    }
    #endif
}
