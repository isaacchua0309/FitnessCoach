//
//  AuthSignInDebugLogger.swift
//  Fitness Coach
//
//  Temporary sign-in trace lines for auth regression debugging.
//  Remove this file once auth stuck-state bugs are verified fixed.
//

import Foundation
import OSLog

enum AuthSignInDebugLogger {

    #if DEBUG
    /// Enabled in DEBUG unless `FITPILOT_AUTH_SIGN_IN_TRACE=0`.
    nonisolated static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["FITPILOT_AUTH_SIGN_IN_TRACE"] != "0"
    }
    #else
    nonisolated static var isEnabled: Bool { false }
    #endif

    nonisolated private static let logger = Logger(subsystem: "FitPilot", category: "AuthSignIn")

    nonisolated static func signInStarted(surface: String) {
        emit("signInStarted", fields: ["surface": surface])
    }

    nonisolated static func signInCancelled(surface: String) {
        emit("signInCancelled", fields: ["surface": surface])
    }

    nonisolated static func signInFailed(surface: String, reason: String) {
        emit("signInFailed", fields: ["surface": surface, "reason": reason])
    }

    nonisolated static func signInSucceeded(uid: String) {
        emit("signInSucceeded", fields: ["uid": ProfileBootstrapDebugLogger.redactedUID(uid)])
    }

    nonisolated static func authGateRenderedSignedOut(route: String) {
        emit("authGateRenderedSignedOut", fields: ["route": route])
    }

    nonisolated static func authGateRenderedSignedIn(route: String) {
        emit("authGateRenderedSignedIn", fields: ["route": route])
    }

    nonisolated private static func emit(_ event: String, fields: [String: String] = [:]) {
        guard isEnabled else { return }

        let fieldLine = fields
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")

        let line = fieldLine.isEmpty
            ? "[AuthSignIn] \(event)"
            : "[AuthSignIn] \(event) \(fieldLine)"

        logger.log(level: .debug, "\(line, privacy: .public)")
    }
}
