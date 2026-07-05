//
//  DeferredAccountDeletionRouter.swift
//  Fitness Coach
//
//  Forma — Routes account deletion completion after the auth shell is available.
//

import Foundation

@MainActor
final class DeferredAccountDeletionRouter: AccountDeletionRouting {

    var onFullAccountDeletion: (() async -> Void)?
    var onLocalDeviceOnlyWipe: (() async -> Void)?

    func routeToSignedOutAfterFullAccountDeletion() async {
        AccountDeletionDebugEventLogger.routerRouteStarted(
            scope: .fullAccount,
            callbackIsNil: onFullAccountDeletion == nil
        )
        await onFullAccountDeletion?()
    }

    func routeToSignedOutAfterLocalDeviceOnlyWipe() async {
        AccountDeletionDebugEventLogger.routerRouteStarted(
            scope: .localDeviceOnly,
            callbackIsNil: onLocalDeviceOnlyWipe == nil
        )
        await onLocalDeviceOnlyWipe?()
    }
}
