//
//  AuthGateCoordinator+ProfileConflictDelegate.swift
//  Fitness Coach
//
//  Delegate bridge for profile conflict coordinator state mutations.
//

import Foundation

extension AuthGateCoordinator: AuthProfileConflictCoordinatorDelegate {

    func currentUID() -> String? {
        authManager.currentUID
    }

    func performUserInitiatedSignOut(source: String) {
        container.publicEntrySessionStore.markUserInitiatedLogout()
        prepareAuthenticatedSignOut(source: source)
        authManager.signOut()
    }
}
