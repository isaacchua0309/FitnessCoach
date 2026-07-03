//
//  AccountSettingsLogoutHandler.swift
//  Fitness Coach
//
//  Forma — Coordinates Account sign-out behavior.
//

import Foundation

enum AccountSettingsLogoutHandler {

    static func perform(
        performAppSignOut: (() -> Void)?,
        authManagerSignOut: () -> Void
    ) {
        if let performAppSignOut {
            performAppSignOut()
        } else {
            authManagerSignOut()
        }
    }
}
