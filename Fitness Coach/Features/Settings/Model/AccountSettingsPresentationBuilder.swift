//
//  AccountSettingsPresentationBuilder.swift
//  Fitness Coach
//
//  Forma — Builds Account settings presentation from auth session data.
//

import Foundation

enum AccountSettingsPresentationBuilder {

    static func build(input: AccountSettingsPresentationInput) -> AccountSettingsPresentation {
        let isSignedIn = isSignedIn(input.authState)
        let showsProgress = showsStatusProgress(input.authState)
        let canLogOut = isSignedIn && !showsProgress

        return AccountSettingsPresentation(
            header: AccountSettingsProfileHeader(
                initials: profileInitials(displayName: input.displayName, email: input.email),
                displayName: normalizedDisplayName(input.displayName),
                email: normalizedEmail(input.email),
                providerBadge: AccountSignInProviderLabels.providerBadge(for: input.signInProvider),
                showsProgress: showsProgress,
                avatarAccessibilityLabel: avatarAccessibilityLabel(displayName: input.displayName)
            ),
            detailRows: detailRows(
                displayName: input.displayName,
                email: input.email,
                signInProvider: input.signInProvider
            ),
            canLogOut: canLogOut,
            logoutButtonAccessibilityHint: canLogOut
                ? FormaProductCopy.Account.signOutHint
                : FormaProductCopy.Account.signOutUnavailableHint,
            logoutConfirmationTitle: FormaProductCopy.Account.logoutConfirmationTitle,
            logoutConfirmationMessage: FormaProductCopy.Account.logoutConfirmationMessage,
            showsProviderBadge: isSignedIn
        )
    }

    // MARK: - Detail rows

    private static func detailRows(
        displayName: String?,
        email: String?,
        signInProvider: AccountSignInProvider
    ) -> [AccountSettingsDetailRow] {
        [
            AccountSettingsDetailRow(
                id: "name",
                label: FormaProductCopy.Account.detailNameLabel,
                value: detailValue(for: displayName, fallback: FormaProductCopy.Account.missingNameFallback),
                allowsTextSelection: false
            ),
            AccountSettingsDetailRow(
                id: "email",
                label: FormaProductCopy.Account.detailEmailLabel,
                value: detailValue(for: email, fallback: FormaProductCopy.Account.missingEmailFallback),
                allowsTextSelection: true
            ),
            AccountSettingsDetailRow(
                id: "sign-in",
                label: FormaProductCopy.Account.detailSignInLabel,
                value: AccountSignInProviderLabels.signInMethod(for: signInProvider),
                allowsTextSelection: false
            )
        ]
    }

    // MARK: - Auth helpers

    private static func isSignedIn(_ authState: AuthState) -> Bool {
        if case .signedIn = authState {
            return true
        }
        return false
    }

    private static func showsStatusProgress(_ authState: AuthState) -> Bool {
        switch authState {
        case .unknown, .signingIn:
            return true
        default:
            return false
        }
    }

    private static func normalizedDisplayName(_ displayName: String?) -> String? {
        guard let displayName = trimmedNonEmpty(displayName) else {
            return nil
        }
        return displayName
    }

    private static func normalizedEmail(_ email: String?) -> String? {
        guard let email = trimmedNonEmpty(email) else {
            return nil
        }
        return email
    }

    private static func detailValue(for value: String?, fallback: String) -> String {
        trimmedNonEmpty(value) ?? fallback
    }

    private static func trimmedNonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func profileInitials(displayName: String?, email: String?) -> String {
        if let name = trimmedNonEmpty(displayName) {
            let parts = name.split(whereSeparator: \.isWhitespace)
            let initials = parts.prefix(2).compactMap(\.first)
            if !initials.isEmpty {
                return String(initials).uppercased()
            }
        }
        if let email = trimmedNonEmpty(email), let first = email.first {
            return String(first).uppercased()
        }
        return "?"
    }

    private static func avatarAccessibilityLabel(displayName: String?) -> String {
        if let name = trimmedNonEmpty(displayName) {
            return "Profile photo for \(name)"
        }
        return FormaProductCopy.Account.avatarAccessibilityLabel
    }
}
