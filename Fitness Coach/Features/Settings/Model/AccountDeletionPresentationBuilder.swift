//
//  AccountDeletionPresentationBuilder.swift
//  Fitness Coach
//
//  Forma — Builds account deletion confirmation copy for Settings.
//

import Foundation

enum AccountDeletionPresentationBuilder {

    static func build(scope: AccountDeletionScope) -> AccountDeletionPresentation {
        let copy = FormaProductCopy.Settings.PrivacyData.self
        switch scope {
        case .fullAccount:
            return AccountDeletionPresentation(
                navigationTitle: copy.deleteAccountConfirmationTitle,
                consequenceBullets: copy.deleteAccountConsequenceBullets,
                confirmActionTitle: copy.deleteAccountConfirmActionTitle,
                confirmActionAccessibilityLabel: copy.deleteAccountConfirmActionTitle,
                confirmActionAccessibilityHint: copy.deleteAccountConfirmAccessibilityHint,
                typedConfirmationPrompt: copy.typedConfirmationPrompt,
                typedConfirmationPlaceholder: copy.typedConfirmationPlaceholder,
                typedConfirmationAccessibilityHint: copy.typedConfirmationAccessibilityHint,
                cancelTitle: copy.deletionFlowCancelTitle,
                cancelAccessibilityHint: copy.deletionFlowCancelAccessibilityHint,
                retryTitle: copy.deletionFlowRetryTitle,
                reauthenticateTitle: copy.deletionFlowReauthenticateTitle,
                reauthenticateAccessibilityHint: copy.deletionFlowReauthenticateAccessibilityHint,
                closeTitle: copy.deletionFlowCloseTitle,
                unavailableTitle: copy.deletionFlowUnavailableTitle,
                unavailableMessage: copy.deletionFlowUnavailableMessage
            )
        case .localDeviceOnly:
            return AccountDeletionPresentation(
                navigationTitle: copy.deleteLocalDeviceDataConfirmationTitle,
                consequenceBullets: copy.deleteLocalDeviceDataConsequenceBullets,
                confirmActionTitle: copy.deleteLocalDeviceDataConfirmActionTitle,
                confirmActionAccessibilityLabel: copy.deleteLocalDeviceDataConfirmActionTitle,
                confirmActionAccessibilityHint: copy.deleteLocalDeviceDataConfirmAccessibilityHint,
                typedConfirmationPrompt: copy.typedConfirmationPrompt,
                typedConfirmationPlaceholder: copy.typedConfirmationPlaceholder,
                typedConfirmationAccessibilityHint: copy.typedConfirmationAccessibilityHint,
                cancelTitle: copy.deletionFlowCancelTitle,
                cancelAccessibilityHint: copy.deletionFlowCancelAccessibilityHint,
                retryTitle: copy.deletionFlowRetryTitle,
                reauthenticateTitle: copy.deletionFlowReauthenticateTitle,
                reauthenticateAccessibilityHint: copy.deletionFlowReauthenticateAccessibilityHint,
                closeTitle: copy.deletionFlowCloseTitle,
                unavailableTitle: copy.deletionFlowUnavailableTitle,
                unavailableMessage: copy.deletionFlowUnavailableMessage
            )
        case .remoteAccountDataOnly:
            return AccountDeletionPresentation(
                navigationTitle: copy.deletionFlowUnavailableTitle,
                consequenceBullets: [copy.deletionFlowUnavailableMessage],
                confirmActionTitle: copy.deletionFlowCloseTitle,
                confirmActionAccessibilityLabel: copy.deletionFlowCloseTitle,
                confirmActionAccessibilityHint: copy.deletionFlowCloseTitle,
                typedConfirmationPrompt: copy.typedConfirmationPrompt,
                typedConfirmationPlaceholder: copy.typedConfirmationPlaceholder,
                typedConfirmationAccessibilityHint: copy.typedConfirmationAccessibilityHint,
                cancelTitle: copy.deletionFlowCancelTitle,
                cancelAccessibilityHint: copy.deletionFlowCancelAccessibilityHint,
                retryTitle: copy.deletionFlowRetryTitle,
                reauthenticateTitle: copy.deletionFlowReauthenticateTitle,
                reauthenticateAccessibilityHint: copy.deletionFlowReauthenticateAccessibilityHint,
                closeTitle: copy.deletionFlowCloseTitle,
                unavailableTitle: copy.deletionFlowUnavailableTitle,
                unavailableMessage: copy.deletionFlowUnavailableMessage
            )
        }
    }
}
