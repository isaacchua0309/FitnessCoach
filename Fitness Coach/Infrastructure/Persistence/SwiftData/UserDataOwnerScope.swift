//
//  UserDataOwnerScope.swift
//  Fitness Coach
//
//  Forma — Local user-data ownership rules for SwiftData reads and writes.
//

import Foundation

/// Centralizes UID scoping for nutrition and related local user data (Phase 1).
enum UserDataOwnerScope {

    /// UID stamped on new rows at write time. Nil when the session is unsigned.
    static func ownerUIDForNewWrite(sessionUID: String?) -> String? {
        sessionUID
    }

    /// Whether a persisted row is visible to the current session.
    ///
    /// - Signed in: only rows owned by the current Firebase UID.
    /// - Signed out: only unowned rows (pre-auth local data).
    static func isVisible(entityOwnerUID: String?, sessionUID: String?) -> Bool {
        switch sessionUID {
        case let uid?:
            return entityOwnerUID == uid
        case nil:
            return entityOwnerUID == nil
        }
    }
}
