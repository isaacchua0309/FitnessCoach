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
        FormaLogRedactor.redactUID(uid)
    }

    /// Emits structured `[ProfileBootstrap]` lines to the unified log.
    nonisolated static func event(_ message: String, fields: [String: String] = [:]) {
        emit(levelName: "info", osLogType: .info, message: message, fields: fields)
    }

    nonisolated static func warn(_ message: String, fields: [String: String] = [:]) {
        emit(levelName: "warn", osLogType: .default, message: message, fields: fields)
    }

    nonisolated static func error(_ message: String, fields: [String: String] = [:], underlying: Error? = nil) {
        var merged = LogRedactor.sanitizeLogFields(fields)
        if let underlying {
            merged.merge(LogRedactor.safeErrorFields(from: underlying, includeDescription: false)) { _, new in new }
            #if DEBUG
            merged.merge(LogRedactor.safeErrorFields(from: underlying, includeDescription: true)) { _, new in new }
            #endif
        }
        emit(levelName: "error", osLogType: .error, message: message, fields: merged)
    }

    #if DEBUG
    nonisolated static var isVerboseEnabled: Bool { FormaAbTest.Diagnostics.profileBootstrapTrace }
    #else
    nonisolated static var isVerboseEnabled: Bool { FormaAbTest.Diagnostics.profileBootstrapTrace }
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

        let sanitized = LogRedactor.sanitizeLogFields(fields)
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
}
