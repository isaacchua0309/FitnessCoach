//
//  AccountDeletionStatusFormatting.swift
//  Fitness Coach
//
//  Forma — User-facing progress labels for account deletion.
//

import Foundation

enum AccountDeletionStatusFormatting {

    static func progressLabel(for status: AccountDeletionStatus) -> String {
        switch status {
        case .preparing, .stoppingSync:
            return FormaProductCopy.Settings.PrivacyData.deletionProgressPreparing
        case .deletingRemoteData:
            return FormaProductCopy.Settings.PrivacyData.deletionProgressDeletingAccountData
        case .deletingAuthAccount:
            return FormaProductCopy.Settings.PrivacyData.deletionProgressDeletingAccount
        case .wipingLocalData:
            return FormaProductCopy.Settings.PrivacyData.deletionProgressRemovingLocalData
        case .completed:
            return FormaProductCopy.Settings.PrivacyData.deletionProgressCompleted
        case .notStarted, .confirming, .cancelled, .failed, .partial,
             .reauthenticationRequired, .offline:
            return ""
        }
    }
}
