//
//  UserDataOwnerScope.swift
//  Fitness Coach
//
//  Forma — Repository-facing shim over `UserDataOwnership` (Phase 1).
//

import Foundation

/// Centralizes UID scoping for nutrition and related local user data (Phase 1).
enum UserDataOwnerScope {

    /// UID stamped on new rows at write time. Nil when the session is unsigned.
    static func ownerUIDForNewWrite(sessionUID: String?) -> String? {
        sessionUID
    }

    /// Whether a persisted row is visible to the current session.
    static func isVisible(entityOwnerUID: String?, sessionUID: String?) -> Bool {
        UserDataOwnership.canRead(ownerUID: entityOwnerUID, currentUID: sessionUID)
    }
}
