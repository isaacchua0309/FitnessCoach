//
//  AccountSettingsPresentationModels.swift
//  Fitness Coach
//
//  Forma — Presentation models for Settings → Account.
//

import Foundation

struct AccountSettingsPresentationInput: Equatable, Sendable {
    let authState: AuthState
    let displayName: String?
    let email: String?
    let signInProvider: AccountSignInProvider
}

struct AccountSettingsProfileHeader: Equatable, Sendable {
    let initials: String
    let displayName: String?
    let email: String?
    let providerBadge: String
    let showsProgress: Bool
    let avatarAccessibilityLabel: String
}

struct AccountSettingsDetailRow: Equatable, Identifiable, Sendable {
    let id: String
    let label: String
    let value: String
    let allowsTextSelection: Bool
}

struct AccountSettingsPresentation: Equatable, Sendable {
    let header: AccountSettingsProfileHeader
    let detailRows: [AccountSettingsDetailRow]
    let canLogOut: Bool
    let logoutButtonAccessibilityHint: String
    let logoutConfirmationTitle: String
    let logoutConfirmationMessage: String
    let showsProviderBadge: Bool
}
