//
//  UserDataOwnership.swift
//  Fitness Coach
//
//  Forma — UID ownership helpers for local user-data reads and writes (Phase 1).
//

import Foundation

enum UserDataOwnership {

    /// Returns a non-empty UID for operations that require an authenticated account.
    static func requireUID(_ uid: String?, operation: String) throws -> String {
        guard let uid else {
            let message = FormaAbTest.Auth.requiresSignInBeforeOnboarding
                ? "Sign in is required before \(operation)."
                : "No account UID is available for \(operation)."
            throw ServiceError.invalidInput(message)
        }

        let trimmed = uid.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ServiceError.invalidInput("A valid account UID is required for \(operation).")
        }
        return trimmed
    }

    /// Whether a persisted row is visible to the current session.
    ///
    /// - Signed in: only rows where `ownerUID == currentUID` (nil rows are excluded).
    /// - Signed out: only unowned rows (`ownerUID == nil`).
    static func canRead(ownerUID: String?, currentUID: String?) -> Bool {
        switch currentUID {
        case let uid?:
            return ownerUID == uid
        case nil:
            return ownerUID == nil
        }
    }
}
