//
//  ProfileBootstrapDebugLogger.swift
//  Fitness Coach
//
//  Forma — DEBUG console tracing for cloud profile bootstrap.
//

import Foundation

#if DEBUG
import OSLog
#endif

enum ProfileBootstrapDebugLogger {

    static func event(_ message: String, fields: [String: String] = [:]) {
        #if DEBUG
        let fieldLine = fields
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")

        let line = fieldLine.isEmpty
            ? "[ProfileBootstrap] \(message)"
            : "[ProfileBootstrap] \(message) \(fieldLine)"

        logger.info("\(line, privacy: .public)")
        #endif
    }

    static func warn(_ message: String, fields: [String: String] = [:]) {
        #if DEBUG
        var merged = fields
        merged["level"] = "warn"
        emit(message: message, fields: merged, log: { logger.warning("\($0, privacy: .public)") })
        #endif
    }

    static func error(_ message: String, fields: [String: String] = [:], underlying: Error? = nil) {
        #if DEBUG
        var merged = fields
        merged["level"] = "error"
        if let underlying {
            merged["error"] = String(describing: underlying)
            let nsError = underlying as NSError
            if !nsError.domain.isEmpty {
                merged["errorDomain"] = nsError.domain
                merged["errorCode"] = String(nsError.code)
            }
        }
        emit(message: message, fields: merged, log: { logger.error("\($0, privacy: .public)") })
        #endif
    }

    #if DEBUG
    private static let logger = Logger(subsystem: "FitPilot", category: "ProfileBootstrap")

    private static func emit(
        message: String,
        fields: [String: String],
        log: (String) -> Void
    ) {
        let fieldLine = fields
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")
        let line = fieldLine.isEmpty
            ? "[ProfileBootstrap] \(message)"
            : "[ProfileBootstrap] \(message) \(fieldLine)"
        log(line)
    }
    #endif
}
