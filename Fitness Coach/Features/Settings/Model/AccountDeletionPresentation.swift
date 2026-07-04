//
//  AccountDeletionPresentation.swift
//  Fitness Coach
//
//  Forma — Presentation models for account deletion confirmation UI.
//

import Foundation

struct AccountDeletionPresentation: Equatable, Sendable {
    let navigationTitle: String
    let consequenceBullets: [String]
    let confirmActionTitle: String
    let confirmActionAccessibilityLabel: String
    let confirmActionAccessibilityHint: String
    let typedConfirmationPrompt: String
    let typedConfirmationPlaceholder: String
    let typedConfirmationAccessibilityHint: String
    let cancelTitle: String
    let cancelAccessibilityHint: String
    let retryTitle: String
    let reauthenticateTitle: String
    let reauthenticateAccessibilityHint: String
    let closeTitle: String
    let unavailableTitle: String
    let unavailableMessage: String
}

enum SettingsDeleteDataResult: Equatable, Sendable {
    case opensDeletionFlow
    case unavailable
}

extension AccountDeletionScope: Identifiable {
    public var id: String { rawValue }
}
