//
//  ProfileOwnershipStatus.swift
//  Fitness Coach
//
//  Forma — Local profile ownership relative to a signed-in Firebase UID.
//

import Foundation

enum ProfileOwnershipStatus: Equatable, Sendable {
    /// No local profile, or `ownerUID` is unset (pre-auth, legacy, uncertain).
    case unowned
    /// Local profile is bound to the active signed-in account.
    case matchesSession
    /// Local profile belongs to a different Firebase account.
    case mismatched(localOwnerUID: String)
}
