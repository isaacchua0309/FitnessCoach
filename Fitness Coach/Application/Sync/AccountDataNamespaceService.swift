//
//  AccountDataNamespaceService.swift
//  Fitness Coach
//
//  Forma — Tracks the active local data namespace UID for multi-user safety (Phase 1).
//
//  Phase 1 relies on strict read filtering — this service does not delete SwiftData rows.
//

import Foundation
import OSLog

@MainActor
final class AccountDataNamespaceService {

    static let lastActiveUIDKey = "forma.accountDataNamespace.lastActiveUID"

    private let userDefaults: UserDefaults
    private let uidProvider: any AccountUIDProviding
    private let logger = Logger(subsystem: "FitPilot", category: "AccountDataNamespace")

    init(
        userDefaults: UserDefaults = .standard,
        uidProvider: any AccountUIDProviding
    ) {
        self.userDefaults = userDefaults
        self.uidProvider = uidProvider
    }

    /// Records the signed-in account as the active local data namespace.
    func prepareForSignedInUID(_ uid: String) async {
        let trimmed = uid.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let previousUID = currentDataNamespaceUID()
        if isAccountSwitch(from: previousUID, to: trimmed) {
            logEvent(
                "account_data_namespace_switch",
                fields: [
                    "fromUID": redactedUID(previousUID),
                    "toUID": redactedUID(trimmed)
                ]
            )
        } else {
            logEvent(
                "account_data_namespace_prepared",
                fields: ["uid": redactedUID(trimmed)]
            )
        }

        userDefaults.set(trimmed, forKey: Self.lastActiveUIDKey)

        if uidProvider.currentUID != trimmed {
            logEvent(
                "account_data_namespace_uid_provider_mismatch",
                fields: [
                    "namespaceUID": redactedUID(trimmed),
                    "providerUID": redactedUID(uidProvider.currentUID)
                ]
            )
        }
    }

    /// Clears the active namespace when the session ends.
    func prepareForSignOut() async {
        logEvent("account_data_namespace_sign_out", fields: [:])
        userDefaults.removeObject(forKey: Self.lastActiveUIDKey)
    }

    /// Last UID recorded as the active local data namespace, if any.
    func currentDataNamespaceUID() -> String? {
        userDefaults.string(forKey: Self.lastActiveUIDKey)
    }

    /// True when switching from one signed-in account to another on the same device.
    func isAccountSwitch(from oldUID: String?, to newUID: String) -> Bool {
        guard let oldUID else { return false }
        return oldUID != newUID
    }

    // MARK: - Logging

    private func logEvent(_ message: String, fields: [String: String]) {
        #if DEBUG
        guard FormaAbTest.Diagnostics.profileBootstrapTrace else { return }
        #endif

        let fieldLine = fields
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")

        let line = fieldLine.isEmpty
            ? "[AccountDataNamespace] \(message)"
            : "[AccountDataNamespace] \(message) \(fieldLine)"

        logger.info("\(line, privacy: .public)")
    }

    private func redactedUID(_ uid: String?) -> String {
        guard let uid else { return "none" }
        return ProfileBootstrapDebugLogger.redactedUID(uid)
    }
}
