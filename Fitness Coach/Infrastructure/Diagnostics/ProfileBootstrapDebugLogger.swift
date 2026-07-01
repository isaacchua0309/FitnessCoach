//
//  ProfileBootstrapDebugLogger.swift
//  Fitness Coach
//
//  Forma — OSLog tracing for local/cloud profile bootstrap (release-safe).
//

import Foundation
import OSLog

enum ProfileBootstrapDebugLogger {

    nonisolated private static let logger = Logger(subsystem: "FitPilot", category: "ProfileBootstrap")

    /// Redacts Firebase UID for logs (suffix only).
    nonisolated static func redactedUID(_ uid: String) -> String {
        guard uid.count > 6 else { return "***" }
        return "***\(uid.suffix(6))"
    }

    /// Emits structured `[ProfileBootstrap]` lines to the unified log.
    nonisolated static func event(_ message: String, fields: [String: String] = [:]) {
        emit(levelName: "info", osLogType: .info, message: message, fields: fields)
    }

    nonisolated static func warn(_ message: String, fields: [String: String] = [:]) {
        emit(levelName: "warn", osLogType: .default, message: message, fields: fields)
    }

    nonisolated static func error(_ message: String, fields: [String: String] = [:], underlying: Error? = nil) {
        var merged = sanitizeFields(fields)
        if let underlying {
            merged["error"] = String(describing: underlying)
            let nsError = underlying as NSError
            if !nsError.domain.isEmpty {
                merged["errorDomain"] = nsError.domain
                merged["errorCode"] = String(nsError.code)
            }
            #if DEBUG
            if !nsError.localizedDescription.isEmpty {
                merged["errorDescription"] = nsError.localizedDescription
            }
            #endif
        }
        emit(levelName: "error", osLogType: .error, message: message, fields: merged)
    }

    #if DEBUG
    /// Enabled in DEBUG unless `FITPILOT_PROFILE_BOOTSTRAP_TRACE=0`.
    nonisolated static var isVerboseEnabled: Bool {
        ProcessInfo.processInfo.environment["FITPILOT_PROFILE_BOOTSTRAP_TRACE"] != "0"
    }
    #else
    nonisolated static var isVerboseEnabled: Bool { true }
    #endif

    nonisolated private static func emit(
        levelName: String,
        osLogType: OSLogType,
        message: String,
        fields: [String: String]
    ) {
        #if DEBUG
        guard isVerboseEnabled else { return }
        #endif

        let sanitized = sanitizeFields(fields)
        var merged = sanitized
        merged["level"] = levelName

        let fieldLine = merged
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")

        let line = fieldLine.isEmpty
            ? "[ProfileBootstrap] \(message)"
            : "[ProfileBootstrap] \(message) \(fieldLine)"

        logger.log(level: osLogType, "\(line, privacy: .public)")
    }

    nonisolated private static func sanitizeFields(_ fields: [String: String]) -> [String: String] {
        var result = fields
        if let uid = result["uid"] {
            result["uid"] = redactedUID(uid)
        }
        return result
    }
}
