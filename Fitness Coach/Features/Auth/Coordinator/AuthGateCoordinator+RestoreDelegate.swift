//
//  AuthGateCoordinator+RestoreDelegate.swift
//  Fitness Coach
//
//  Account restore intent forwarding and delegate bridge for AuthRestoreShellCoordinator.
//

import Foundation

extension AuthGateCoordinator: AuthRestoreShellCoordinatorDelegate {}

extension AuthGateCoordinator {

    // MARK: - Account restore routing

    func routeToMainWithAccountRestore(uid: String, reason: AccountRestoreReason) {
        restoreShellCoordinator.routeToMainWithAccountRestore(uid: uid, reason: reason)
    }

    func completeRouteToMain(uid: String, restoreSummary: AccountRestoreSummary? = nil) {
        restoreShellCoordinator.completeRouteToMain(uid: uid, restoreSummary: restoreSummary)
    }

    func scheduleRouteToMainWithAccountRestore(uid: String, reason: AccountRestoreReason) {
        restoreShellCoordinator.scheduleRouteToMainWithAccountRestore(uid: uid, reason: reason)
    }

    func retryAccountRestore() {
        restoreShellCoordinator.retryAccountRestore()
    }
}
