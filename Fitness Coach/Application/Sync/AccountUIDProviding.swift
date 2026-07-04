//
//  AccountUIDProviding.swift
//  Fitness Coach
//
//  Forma — Active signed-in account UID for sync coordinators (Phase 5).
//

import Foundation

/// Supplies the currently signed-in Firebase UID for sync and restore coordinators.
protocol AccountUIDProviding: AnyObject {
    func currentUID() -> String?
}

/// Closure-backed UID provider used by coordinators and lifecycle hooks.
final class ClosureAccountUIDProvider: AccountUIDProviding {

    private let provider: () -> String?

    init(_ provider: @escaping () -> String?) {
        self.provider = provider
    }

    func currentUID() -> String? {
        provider()
    }
}
