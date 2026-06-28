//
//  AccountMismatchOutcome.swift
//  Fitness Coach
//
//  Forma — Results for account mismatch resolution actions.
//

import Foundation

enum AccountMismatchRestoreOutcome: Equatable, Sendable {
    case restoredToMain
    case missingCloudProfile
    case cloudFetchFailed
}

enum AccountMismatchUseDeviceOutcome: Equatable, Sendable {
    case cloudProfileConflict(CloudUserProfileDocument)
    /// Cloud absent — user must confirm before linking the on-device profile.
    case requiresLocalLinkConfirmation
    case cloudFetchFailed
}
