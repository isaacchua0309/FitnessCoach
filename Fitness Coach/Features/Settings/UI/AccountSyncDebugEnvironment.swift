//
//  AccountSyncDebugEnvironment.swift
//  Fitness Coach
//
//  Forma — DEBUG-only environment hook for account sync diagnostics.
//

#if DEBUG
import Foundation

struct AccountSyncDebugActions {
    var pendingMutationCount: () async -> Int
    var lastSnapshot: () -> AccountSyncDiagnosticsSnapshot?
    var triggerManualSync: () async -> AccountSyncDiagnosticsSnapshot?
}

import SwiftUI

private struct AccountSyncDebugActionsKey: EnvironmentKey {
    static let defaultValue: AccountSyncDebugActions? = nil
}

extension EnvironmentValues {
    var accountSyncDebugActions: AccountSyncDebugActions? {
        get { self[AccountSyncDebugActionsKey.self] }
        set { self[AccountSyncDebugActionsKey.self] = newValue }
    }
}
#endif
