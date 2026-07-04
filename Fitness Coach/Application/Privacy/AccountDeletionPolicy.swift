//
//  AccountDeletionPolicy.swift
//  Fitness Coach
//
//  Forma — Centralized account deletion policy (Phase 6).
//
//  Scope rules, confirmation gates, timeouts, and exclusions. No deletion coordinator wiring yet.
//

import Foundation

/// Central policy for in-app account deletion and privacy controls.
enum AccountDeletionPolicy {

    // MARK: - Confirmation

    /// Full account deletion requires an explicit typed confirmation phrase.
    static let requiresTypedConfirmation = true

    /// User must type this phrase to confirm destructive deletion.
    static let confirmationPhrase = "DELETE"

    // MARK: - Scope availability

    /// Settings may offer “delete local device data only” without removing the cloud account.
    static let allowLocalDeviceOnlyWipe = true

    /// Remote-only deletion is off unless product explicitly enables it.
    static let allowRemoteOnlyDelete = false

    // MARK: - Exclusions (never delete via this flow)

    /// Raw meal image bytes are not uploaded by default and are not targeted for cloud deletion.
    static let deleteRawMealImages = false

    /// Apple Health / HealthKit samples remain on the device and in Apple Health.
    static let deleteRawHealthKitFromAppleHealth = false

    // MARK: - Timeouts (seconds)

    /// Upper bound for remote Firestore deletion orchestration.
    static let maximumRemoteDeleteSeconds = 60

    /// Upper bound for local SwiftData / cache / preference wipe.
    static let maximumLocalWipeSeconds = 30

    // MARK: - Scope rules

    /// Returns whether the given scope is enabled for user-facing deletion affordances.
    static func isScopeEnabled(_ scope: AccountDeletionScope) -> Bool {
        switch scope {
        case .fullAccount:
            return true
        case .localDeviceOnly:
            return allowLocalDeviceOnlyWipe
        case .remoteAccountDataOnly:
            return allowRemoteOnlyDelete
        }
    }

    /// Ordered phases for a full account deletion (remote → Auth → local).
    static func phases(for scope: AccountDeletionScope) -> [AccountDeletionStatus] {
        switch scope {
        case .fullAccount:
            return [
                .preparing,
                .stoppingSync,
                .deletingRemoteData,
                .deletingAuthAccount,
                .wipingLocalData,
                .completed
            ]
        case .localDeviceOnly:
            return [
                .preparing,
                .stoppingSync,
                .wipingLocalData,
                .completed
            ]
        case .remoteAccountDataOnly:
            return [
                .preparing,
                .stoppingSync,
                .deletingRemoteData,
                .completed
            ]
        }
    }

    /// Whether deletion may proceed for `targetUID` when the active session UID is `sessionUID`.
    ///
    /// Deletion is always scoped to the signed-in account. Another user's data must never be deleted.
    static func mayDeleteData(for targetUID: String, sessionUID: String?) -> Bool {
        guard let sessionUID else { return false }
        guard let normalizedTarget = normalizedUID(targetUID),
              let normalizedSession = normalizedUID(sessionUID) else {
            return false
        }
        return normalizedTarget == normalizedSession
    }

    /// Whether an in-flight coordinated deletion may continue for `targetUID`.
    static func mayContinueDeletion(for targetUID: String, authorizedUID: String) -> Bool {
        guard let normalizedTarget = normalizedUID(targetUID),
              let normalizedAuthorized = normalizedUID(authorizedUID) else {
            return false
        }
        return normalizedTarget == normalizedAuthorized
    }

    /// Privacy-safe diagnostics field: UID prefix only, never full payload contents.
    static func privacySafeUIDField(_ uid: String) -> String {
        let trimmed = uid.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 8 else { return "uid_redacted" }
        return String(trimmed.prefix(8)) + "…"
    }

    // MARK: - Product copy guardrails

    /// Messaging must not claim deletion of raw Apple Health data.
    static let excludesAppleHealthDeletionClaim = true

    /// Messaging must not claim deletion of the user's Google account.
    static let excludesGoogleAccountDeletionClaim = true

    static var maximumRemoteDeleteInterval: TimeInterval {
        TimeInterval(maximumRemoteDeleteSeconds)
    }

    static var maximumLocalWipeInterval: TimeInterval {
        TimeInterval(maximumLocalWipeSeconds)
    }

    // MARK: - Private

    private static func normalizedUID(_ uid: String) -> String? {
        try? AccountSyncMutationValidation.normalizedOwnerUID(uid)
    }
}
