//
//  TodayHydrationDebugLogger.swift
//  Fitness Coach
//
//  OSLog tracing for Today daily-log hydration (release-safe).
//

import Foundation
import OSLog

enum TodayHydrationDebugLogger {

    nonisolated private static let logger = Logger(subsystem: "FitPilot", category: "TodayHydration")

    nonisolated static func deferred(
        authState: AuthState,
        profileOwnerUID: String?,
        reason: String
    ) {
        emit(
            levelName: "info",
            osLogType: .info,
            message: "today_load_deferred",
            fields: [
                "authState": authStateLabel(authState),
                "profileOwnerUID": profileOwnerUID.map(ProfileBootstrapDebugLogger.redactedUID) ?? "none",
                "reason": reason
            ]
        )
    }

    nonisolated static func loadStarted(
        context: TodayHydrationContext,
        isRefresh: Bool,
        viewState: String
    ) {
        emit(
            levelName: "info",
            osLogType: .info,
            message: "today_load_started",
            fields: [
                "uid": context.sessionUID,
                "profileOwnerUID": context.profileOwnerUID,
                "dailyLogDateKey": ISO8601DateFormatter().string(from: context.dailyLogDateKey),
                "isRefresh": isRefresh ? "true" : "false",
                "viewState": viewState
            ]
        )
    }

    nonisolated static func loadSucceeded(context: TodayHydrationContext, isRefresh: Bool) {
        emit(
            levelName: "info",
            osLogType: .info,
            message: "today_load_succeeded",
            fields: [
                "uid": context.sessionUID,
                "dailyLogDateKey": ISO8601DateFormatter().string(from: context.dailyLogDateKey),
                "isRefresh": isRefresh ? "true" : "false"
            ]
        )
    }

    nonisolated static func loadFailed(
        context: TodayHydrationContext?,
        isRefresh: Bool,
        keptStaleLoadedState: Bool,
        error: Error
    ) {
        var fields: [String: String] = [
            "isRefresh": isRefresh ? "true" : "false",
            "keptStaleLoadedState": keptStaleLoadedState ? "true" : "false",
            "error": String(describing: error)
        ]
        if let context {
            fields["uid"] = context.sessionUID
            fields["dailyLogDateKey"] = ISO8601DateFormatter().string(from: context.dailyLogDateKey)
        }
        let nsError = error as NSError
        if !nsError.domain.isEmpty {
            fields["errorDomain"] = nsError.domain
            fields["errorCode"] = String(nsError.code)
        }
        emit(levelName: "error", osLogType: .error, message: "today_load_failed", fields: fields)
    }

    nonisolated static func sessionRebound(from previousUID: String?, to uid: String) {
        emit(
            levelName: "info",
            osLogType: .info,
            message: "today_session_rebound",
            fields: [
                "previousUID": previousUID.map(ProfileBootstrapDebugLogger.redactedUID) ?? "none",
                "uid": uid
            ]
        )
    }

    #if DEBUG
    nonisolated static var isVerboseEnabled: Bool {
        ProcessInfo.processInfo.environment["FITPILOT_TODAY_HYDRATION_TRACE"] != "0"
    }
    #endif

    nonisolated private static func authStateLabel(_ authState: AuthState) -> String {
        switch authState {
        case .unknown: return "unknown"
        case .signedOut: return "signedOut"
        case .signingIn: return "signingIn"
        case .signedIn: return "signedIn"
        case .failed: return "failed"
        }
    }

    nonisolated private static func emit(
        levelName: String,
        osLogType: OSLogType,
        message: String,
        fields: [String: String]
    ) {
        #if DEBUG
        guard isVerboseEnabled else { return }

        var merged = fields
        merged["level"] = levelName
        if let uid = merged["uid"] {
            merged["uid"] = ProfileBootstrapDebugLogger.redactedUID(uid)
        }
        if let ownerUID = merged["profileOwnerUID"], ownerUID != "none" {
            merged["profileOwnerUID"] = ProfileBootstrapDebugLogger.redactedUID(ownerUID)
        }

        let fieldLine = merged
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")

        let line = fieldLine.isEmpty
            ? "[TodayHydration] \(message)"
            : "[TodayHydration] \(message) \(fieldLine)"

        logger.log(level: osLogType, "\(line, privacy: .public)")
        #endif
    }
}
