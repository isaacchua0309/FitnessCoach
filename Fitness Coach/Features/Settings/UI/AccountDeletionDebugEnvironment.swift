//
//  AccountDeletionDebugEnvironment.swift
//  Fitness Coach
//
//  Forma — DEBUG-only environment hook for account deletion dry-run verification.
//

#if DEBUG
import Foundation
import SwiftUI

struct AccountDeletionDebugActions {
    var verifyDeleteEndpointDryRun: () async throws -> AccountDeletionDryRunVerificationResult
}

private struct AccountDeletionDebugActionsKey: EnvironmentKey {
    static let defaultValue: AccountDeletionDebugActions? = nil
}

extension EnvironmentValues {
    var accountDeletionDebugActions: AccountDeletionDebugActions? {
        get { self[AccountDeletionDebugActionsKey.self] }
        set { self[AccountDeletionDebugActionsKey.self] = newValue }
    }
}
#endif
