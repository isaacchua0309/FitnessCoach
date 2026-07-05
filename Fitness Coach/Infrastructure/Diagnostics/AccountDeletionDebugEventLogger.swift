//
//  AccountDeletionDebugEventLogger.swift
//  Fitness Coach
//
//  Forma — Debug-only, privacy-safe account deletion diagnostic events.
//
//  Enable via `FormaAbTest.Diagnostics.accountDeletionTrace`.
//  Never logs raw UID, email, tokens, or user content.
//

import Foundation
import OSLog

enum AccountDeletionDebugEventLogger {

    /// Diagnostic phases for correlating delete-flow regressions in Xcode Console.
    enum Phase: String, Sendable {
        case preparing
        case deletingRemoteData
        case deletingFirebaseAuth
        case wipingLocalData
        case routingSignedOut
        case completed
        case failed
        case partial
        case cancelled
    }

    nonisolated static var isEnabled: Bool {
        FormaAbTest.Diagnostics.accountDeletionTrace
    }

    nonisolated private static let logger = Logger(
        subsystem: "Forma",
        category: "AccountDeletionDebug"
    )

    // MARK: - Settings / UI

    nonisolated static func settingsOpenAccountDeletion(
        scope: AccountDeletionScope,
        coordinatorIsNil: Bool
    ) {
        emit("settings_open_account_deletion", fields: [
            "scope": scope.rawValue,
            "coordinatorIsNil": String(coordinatorIsNil),
        ])
    }

    nonisolated static func settingsCoordinatorConfigured(coordinatorIsNil: Bool) {
        emit("settings_coordinator_configured", fields: [
            "coordinatorIsNil": String(coordinatorIsNil),
        ])
    }

    nonisolated static func settingsDeleteDataAction(
        scope: AccountDeletionScope,
        result: SettingsDeleteDataResult
    ) {
        emit("settings_delete_data_action", fields: [
            "scope": scope.rawValue,
            "result": settingsDeleteDataResultLabel(result),
        ])
    }

    nonisolated static func viewModelConfirmDeletion(
        scope: AccountDeletionScope,
        coordinatorIsNil: Bool
    ) {
        emit("view_model_confirm_deletion", fields: [
            "scope": scope.rawValue,
            "coordinatorIsNil": String(coordinatorIsNil),
        ])
    }

    nonisolated static func viewModelRetryDeletion(
        scope: AccountDeletionScope,
        priorStatus: AccountDeletionStatus?
    ) {
        var fields: [String: String] = ["scope": scope.rawValue]
        if let priorStatus {
            fields["priorStatus"] = priorStatus.rawValue
        }
        emit("view_model_retry_deletion", fields: fields)
    }

    // MARK: - Coordinator

    nonisolated static func coordinatorDeleteAccountInvoked(scope: AccountDeletionScope) {
        emit("coordinator_delete_account_invoked", fields: [
            "scope": scope.rawValue,
        ])
    }

    nonisolated static func coordinatorRunDeletionStarted(
        scope: AccountDeletionScope,
        runToken: UUID,
        resumeFromReauth: Bool,
        uidHash: String?
    ) {
        var fields: [String: String] = [
            "scope": scope.rawValue,
            "runToken": runToken.uuidString,
            "resumeFromReauth": String(resumeFromReauth),
        ]
        if let uidHash {
            fields["uidHash"] = uidHash
        }
        emit("coordinator_run_deletion_started", fields: fields)
    }

    nonisolated static func coordinatorPhaseTransition(
        phase: Phase,
        scope: AccountDeletionScope,
        runToken: UUID?,
        uidHash: String? = nil
    ) {
        var fields: [String: String] = [
            "phase": phase.rawValue,
            "scope": scope.rawValue,
        ]
        if let runToken {
            fields["runToken"] = runToken.uuidString
        }
        if let uidHash {
            fields["uidHash"] = uidHash
        }
        emit("coordinator_phase_transition", fields: fields)
    }

    nonisolated static func coordinatorTerminalSummary(
        summary: AccountDeletionSummary,
        runToken: UUID?
    ) {
        var fields: [String: String] = [
            "scope": summary.scope.rawValue,
            "status": summary.status.rawValue,
            "authAccountDeleted": String(summary.authAccountDeleted),
            "remoteProfileDeleted": String(summary.remoteProfileDeleted),
        ]
        if let runToken {
            fields["runToken"] = runToken.uuidString
        }
        if let category = summary.failureCategory?.rawValue {
            fields["failureCategory"] = category
        }
        if !summary.uid.isEmpty {
            fields["uidHash"] = AccountDeletionPolicy.privacySafeUIDField(summary.uid)
        }
        let level: OSLogType = summary.isSuccessful ? .info : .error
        emit("coordinator_terminal_summary", level: level, fields: fields)
    }

    nonisolated static func coordinatorRunInvalidated(
        reason: String,
        runToken: UUID?,
        scope: AccountDeletionScope
    ) {
        var fields: [String: String] = [
            "reason": reason,
            "scope": scope.rawValue,
        ]
        if let runToken {
            fields["runToken"] = runToken.uuidString
        }
        emit("coordinator_run_invalidated", level: .error, fields: fields)
    }

    // MARK: - Remote HTTP

    nonisolated static func remoteRequestPrepared(
        host: String,
        path: String,
        hasAuthorizationHeader: Bool
    ) {
        emit("remote_request_prepared", fields: [
            "host": host,
            "path": path,
            "hasAuthorizationHeader": String(hasAuthorizationHeader),
        ])
    }

    nonisolated static func remoteRequestFinished(
        host: String,
        path: String,
        statusCode: Int,
        mappedCategory: String,
        durationMs: Int,
        backendErrorCategory: String? = nil
    ) {
        var fields: [String: String] = [
            "host": host,
            "path": path,
            "statusCode": String(statusCode),
            "mappedCategory": mappedCategory,
            "durationMs": String(durationMs),
        ]
        if let backendErrorCategory {
            fields["backendErrorCategory"] = backendErrorCategory
        }
        emit("remote_request_finished", fields: fields)
    }

    nonisolated static func remoteRequestFailed(
        host: String,
        path: String,
        statusCode: Int?,
        mappedCategory: String,
        durationMs: Int? = nil,
        backendErrorCategory: String? = nil
    ) {
        var fields: [String: String] = [
            "host": host,
            "path": path,
            "mappedCategory": mappedCategory,
        ]
        if let statusCode {
            fields["statusCode"] = String(statusCode)
        }
        if let durationMs {
            fields["durationMs"] = String(durationMs)
        }
        if let backendErrorCategory {
            fields["backendErrorCategory"] = backendErrorCategory
        }
        emit("remote_request_failed", level: .error, fields: fields)
    }

    nonisolated static func remoteAuthTokenFailure(mappedCategory: String) {
        emit("remote_auth_token_failure", level: .error, fields: [
            "mappedCategory": mappedCategory,
        ])
    }

    // MARK: - Firebase Auth delete / reauth

    nonisolated static func authDeleteStarted() {
        emit("auth_delete_started")
    }

    nonisolated static func authDeleteSucceeded() {
        emit("auth_delete_succeeded")
    }

    nonisolated static func authDeleteFailed(
        category: String,
        firebaseErrorCode: Int? = nil
    ) {
        var fields: [String: String] = ["category": category]
        if let firebaseErrorCode {
            fields["firebaseErrorCode"] = String(firebaseErrorCode)
        }
        emit("auth_delete_failed", level: .error, fields: fields)
    }

    nonisolated static func reauthStarted() {
        emit("reauth_started")
    }

    nonisolated static func reauthSucceeded() {
        emit("reauth_succeeded")
    }

    nonisolated static func reauthCancelled() {
        emit("reauth_cancelled")
    }

    nonisolated static func reauthFailed(
        category: String,
        firebaseErrorCode: Int? = nil
    ) {
        var fields: [String: String] = ["category": category]
        if let firebaseErrorCode {
            fields["firebaseErrorCode"] = String(firebaseErrorCode)
        }
        emit("reauth_failed", level: .error, fields: fields)
    }

    // MARK: - Local wipe

    nonisolated static func localWipeStarted(
        scope: AccountDeletionScope,
        uidHash: String
    ) {
        emit("local_wipe_started", fields: [
            "scope": scope.rawValue,
            "uidHash": uidHash,
        ])
    }

    nonisolated static func localWipeFinished(
        scope: AccountDeletionScope,
        status: AccountDeletionStatus,
        uidHash: String,
        failureCategory: AccountDeletionFailureCategory? = nil
    ) {
        var fields: [String: String] = [
            "scope": scope.rawValue,
            "status": status.rawValue,
            "uidHash": uidHash,
        ]
        if let failureCategory {
            fields["failureCategory"] = failureCategory.rawValue
        }
        let level: OSLogType = status == .completed ? .info : .error
        emit("local_wipe_finished", level: level, fields: fields)
    }

    // MARK: - Routing

    nonisolated static func routerWired(
        fullAccountCallbackIsNil: Bool,
        localDeviceCallbackIsNil: Bool
    ) {
        emit("router_wired", fields: [
            "fullAccountCallbackIsNil": String(fullAccountCallbackIsNil),
            "localDeviceCallbackIsNil": String(localDeviceCallbackIsNil),
        ])
    }

    nonisolated static func routerRouteStarted(
        scope: AccountDeletionScope,
        callbackIsNil: Bool
    ) {
        emit("router_route_started", fields: [
            "scope": scope.rawValue,
            "callbackIsNil": String(callbackIsNil),
        ])
    }

    nonisolated static func shellResetAfterDeletion(source: String) {
        emit("shell_reset_after_deletion", fields: [
            "source": source,
        ])
    }

    // MARK: - Mapping helpers

    nonisolated static func phase(for status: AccountDeletionStatus) -> Phase {
        switch status {
        case .preparing, .stoppingSync, .confirming, .notStarted:
            return .preparing
        case .deletingRemoteData:
            return .deletingRemoteData
        case .deletingAuthAccount:
            return .deletingFirebaseAuth
        case .wipingLocalData:
            return .wipingLocalData
        case .completed:
            return .completed
        case .failed, .offline:
            return .failed
        case .partial, .reauthenticationRequired:
            return .partial
        case .cancelled:
            return .cancelled
        }
    }

    nonisolated static func terminalPhase(for summary: AccountDeletionSummary) -> Phase {
        switch summary.status {
        case .completed:
            return .completed
        case .cancelled:
            return .cancelled
        case .partial, .reauthenticationRequired:
            return .partial
        case .offline, .failed:
            return .failed
        default:
            return phase(for: summary.status)
        }
    }

    nonisolated static func safeEndpoint(from url: URL) -> (host: String, path: String) {
        let host = url.host?.trimmingCharacters(in: .whitespacesAndNewlines)
        let path = url.path.trimmingCharacters(in: .whitespacesAndNewlines)
        return (
            host?.isEmpty == false ? host! : "unknown_host",
            path.isEmpty ? "/" : path
        )
    }

    nonisolated static func firebaseAuthErrorCode(from error: Error) -> Int? {
        let nsError = error as NSError
        guard nsError.domain == AuthAccountDeletionErrorClassifier.firebaseAuthErrorDomain else {
            return nil
        }
        return nsError.code
    }

    nonisolated static func authDeletionCategoryLabel(_ error: AccountAuthDeletionError) -> String {
        AuthAccountDeletionErrorClassifier.errorCategory(error)
    }

    nonisolated static func remoteErrorCategoryLabel(_ error: AccountDeletionRemoteError) -> String {
        switch error {
        case .unauthenticated:
            return "unauthorized"
        case .reauthenticationRequired:
            return "requiresRecentLogin"
        case .offline:
            return "offline"
        case .permissionDenied:
            return "forbidden"
        case .serverUnavailable:
            return "serverUnavailable"
        case .timeout:
            return "timeout"
        case .unknown(let reason):
            if reason?.localizedCaseInsensitiveContains("not found") == true {
                return "notFound"
            }
            return "unknown"
        }
    }

    nonisolated static func httpStatusMappedCategory(
        statusCode: Int,
        mapped: AccountDeletionRemoteError
    ) -> String {
        if statusCode == 404 {
            return "notFound"
        }
        return remoteErrorCategoryLabel(mapped)
    }

    // MARK: - Private

    nonisolated private static func settingsDeleteDataResultLabel(
        _ result: SettingsDeleteDataResult
    ) -> String {
        switch result {
        case .opensDeletionFlow:
            return "opensDeletionFlow"
        case .unavailable:
            return "unavailable"
        }
    }

    nonisolated private static func emit(
        _ event: String,
        level: OSLogType = .debug,
        fields: [String: String] = [:]
    ) {
        guard isEnabled else { return }

        let sanitized = LogRedactor.sanitizeLogFields(fields)
        let fieldLine = sanitized
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")

        let line = fieldLine.isEmpty
            ? "[AccountDeletionDebug] \(event)"
            : "[AccountDeletionDebug] \(event) \(fieldLine)"

        logger.log(level: level, "\(line, privacy: .public)")
    }
}
