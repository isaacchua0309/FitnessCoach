//
//  AppSignOutEnvironment.swift
//  Fitness Coach
//
//  Routes Account logout through the auth-gate coordinator (root shell reset).
//

import SwiftUI

private struct PerformAppSignOutKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

extension EnvironmentValues {
    /// Performs a full sign-out: clears auth, resets root routing, and returns to welcome.
    var performAppSignOut: (() -> Void)? {
        get { self[PerformAppSignOutKey.self] }
        set { self[PerformAppSignOutKey.self] = newValue }
    }
}
