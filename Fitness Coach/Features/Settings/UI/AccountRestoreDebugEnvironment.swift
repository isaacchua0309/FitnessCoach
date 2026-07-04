//
//  AccountRestoreDebugEnvironment.swift
//  Fitness Coach
//
//  Forma — DEBUG-only environment hook for account restore diagnostics.
//

#if DEBUG
import Foundation

struct AccountRestoreDebugActions {
    var lastSnapshot: () -> AccountRestoreDiagnosticsSnapshot?
    var restoreStateDescription: () -> String
    var triggerManualRetry: () async -> AccountRestoreDiagnosticsSnapshot?
    var resetRestoreMetadata: () -> Void
}

import SwiftUI

private struct AccountRestoreDebugActionsKey: EnvironmentKey {
    static let defaultValue: AccountRestoreDebugActions? = nil
}

extension EnvironmentValues {
    var accountRestoreDebugActions: AccountRestoreDebugActions? {
        get { self[AccountRestoreDebugActionsKey.self] }
        set { self[AccountRestoreDebugActionsKey.self] = newValue }
    }
}
#endif
