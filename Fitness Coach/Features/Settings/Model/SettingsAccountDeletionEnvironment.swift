//
//  SettingsAccountDeletionEnvironment.swift
//  Fitness Coach
//
//  Forma — Injects the account deletion coordinator into Settings.
//

import SwiftUI

private struct AccountDeletionCoordinatorEnvironmentKey: EnvironmentKey {
    static let defaultValue: AccountDeletionCoordinator? = nil
}

extension EnvironmentValues {
    var accountDeletionCoordinator: AccountDeletionCoordinator? {
        get { self[AccountDeletionCoordinatorEnvironmentKey.self] }
        set { self[AccountDeletionCoordinatorEnvironmentKey.self] = newValue }
    }
}
