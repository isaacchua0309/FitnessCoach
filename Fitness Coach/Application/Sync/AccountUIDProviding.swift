//
//  AccountUIDProviding.swift
//  Fitness Coach
//
//  Forma — Active signed-in account UID for sync coordinators (Phase 1 / Phase 5).
//

import Foundation

/// Supplies the currently signed-in Firebase UID for sync, restore, and namespace services.
protocol AccountUIDProviding {
    var currentUID: String? { get }
}

/// Production adapter backed by `AuthManager` — the single auth session source.
@MainActor
final class AuthAccountUIDProvider: AccountUIDProviding {

    private let authManager: AuthManager

    init(authManager: AuthManager) {
        self.authManager = authManager
    }

    var currentUID: String? {
        authManager.currentUID
    }
}

/// Closure-backed UID provider used by coordinators and lifecycle hooks.
final class ClosureAccountUIDProvider: AccountUIDProviding {

    private let provider: () -> String?

    init(_ provider: @escaping () -> String?) {
        self.provider = provider
    }

    var currentUID: String? {
        provider()
    }
}
