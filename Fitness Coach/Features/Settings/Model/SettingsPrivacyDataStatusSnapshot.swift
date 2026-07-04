//
//  SettingsPrivacyDataStatusSnapshot.swift
//  Fitness Coach
//
//  Forma — Safe account/sync status for Privacy & Data settings (counts and timestamps only).
//

import Foundation

struct SettingsPrivacyDataStatusSnapshot: Equatable, Sendable {

    enum AccountConnection: Equatable, Sendable {
        case signedOut
        case signedIn(provider: AccountSignInProvider)
    }

    let accountConnection: AccountConnection
    let lastSuccessfulSyncAt: Date?
    let lastSuccessfulRestoreAt: Date?
    let pendingUploadCount: Int
    let isBlockingRestoreActive: Bool

    static let empty = SettingsPrivacyDataStatusSnapshot(
        accountConnection: .signedOut,
        lastSuccessfulSyncAt: nil,
        lastSuccessfulRestoreAt: nil,
        pendingUploadCount: 0,
        isBlockingRestoreActive: false
    )

    var isSignedIn: Bool {
        if case .signedIn = accountConnection { return true }
        return false
    }
}

struct SettingsPrivacyDataDetailRow: Equatable, Identifiable, Sendable {
    let id: String
    let label: String
    let value: String
}

struct SettingsPrivacyDataAccountStatusPresentation: Equatable, Sendable {
    let screenTitle: String
    let rows: [SettingsPrivacyDataDetailRow]
}

struct SettingsPrivacyDataSyncStatusPresentation: Equatable, Sendable {
    let screenTitle: String
    let rows: [SettingsPrivacyDataDetailRow]
}

struct SettingsPrivacyDataHealthNotePresentation: Equatable, Sendable {
    let screenTitle: String
    let bodyParagraphs: [String]
}
