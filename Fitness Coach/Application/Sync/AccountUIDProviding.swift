//
//  AccountUIDProviding.swift
//  Fitness Coach
//
//  Forma — Abstraction for the active Firebase account UID (Phase 1).
//

import Foundation

/// Supplies the current Firebase UID for local user-data ownership scoping.
protocol AccountUIDProviding {
    var currentUID: String? { get }
}

/// Production adapter backed by `AuthManager` — the single auth session source.
@MainActor
struct AuthAccountUIDProvider: AccountUIDProviding {

    private let authManager: AuthManager

    init(authManager: AuthManager) {
        self.authManager = authManager
    }

    var currentUID: String? {
        authManager.currentUID
    }
}
