//
//  AccountDeletionCoordinatorLogger.swift
//  Fitness Coach
//
//  Forma — Privacy-safe account deletion coordinator diagnostics (Phase 6).
//
//  Logs scope, status, and hashed UID only. Never logs food, profile, or payload bodies.
//

import Foundation
import OSLog

enum AccountDeletionCoordinatorLogger {

    private static let logger = Logger(subsystem: "Forma", category: "AccountDeletion")

    static func flowStarted(scope: AccountDeletionScope, uidField: String) {
        log("flow_started", fields: [
            "scope": scope.rawValue,
            "uidHash": uidField,
        ])
    }

    static func flowFinished(
        scope: AccountDeletionScope,
        status: AccountDeletionStatus,
        uidField: String,
        durationMs: Int
    ) {
        log("flow_finished", fields: [
            "scope": scope.rawValue,
            "status": status.rawValue,
            "uidHash": uidField,
            "durationMs": String(durationMs),
        ])
    }

    static func flowFailed(
        scope: AccountDeletionScope,
        category: String,
        uidField: String
    ) {
        log("flow_failed", level: .error, fields: [
            "scope": scope.rawValue,
            "category": category,
            "uidHash": uidField,
        ])
    }

    static func remoteFailure(
        scope: AccountDeletionScope,
        stage: String,
        category: String,
        retryable: Bool,
        statusCode: Int? = nil,
        uidField: String
    ) {
        var fields: [String: String] = [
            "scope": scope.rawValue,
            "stage": stage,
            "category": category,
            "retryable": retryable ? "yes" : "no",
            "uidHash": uidField,
        ]
        if let statusCode {
            fields["statusCode"] = String(statusCode)
        }
        log("remote_failure", level: .error, fields: fields)
    }

    static func phaseChanged(
        scope: AccountDeletionScope,
        status: AccountDeletionStatus,
        uidField: String
    ) {
        log("phase_changed", fields: [
            "scope": scope.rawValue,
            "status": status.rawValue,
            "uidHash": uidField,
        ])
    }

    private static func log(
        _ event: String,
        level: OSLogType = .info,
        fields: [String: String]
    ) {
        let sanitized = LogRedactor.sanitizeLogFields(fields)
        let fieldLine = sanitized
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")
        logger.log(
            level: level,
            "\(event, privacy: .public) \(fieldLine, privacy: .public)"
        )
    }
}
