//
//  AuthGateCoordinator+RestoreDelegate.swift
//  Fitness Coach
//
//  Delegate bridge for account restore shell coordinator state mutations.
//

import Foundation

extension AuthGateCoordinator: AuthRestoreShellCoordinatorDelegate {

    func currentUID() -> String? {
        authManager.currentUID
    }

    func signOutFromAuthManager() {
        authManager.signOut()
    }
}
