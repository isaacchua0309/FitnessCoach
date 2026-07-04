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
        await onFullAccountDeletion?()
    }

    func routeToSignedOutAfterLocalDeviceOnlyWipe() async {
        await onLocalDeviceOnlyWipe?()
    }
}
