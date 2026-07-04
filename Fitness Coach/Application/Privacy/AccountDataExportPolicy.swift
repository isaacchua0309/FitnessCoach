//
//  AccountDataExportPolicy.swift
//  Fitness Coach
//
//  Forma — Account data export policy (Phase 6).
//

import Foundation

enum AccountDataExportPolicy {

    /// Disabled until product explicitly enables "Download my data".
    static let accountDataExportEnabled = false

    static var isEnabled: Bool { accountDataExportEnabled }

    /// Export is always scoped to the signed-in account.
    static func mayExportData(for targetUID: String, sessionUID: String?) -> Bool {
        AccountDeletionPolicy.mayDeleteData(for: targetUID, sessionUID: sessionUID)
    }
}
