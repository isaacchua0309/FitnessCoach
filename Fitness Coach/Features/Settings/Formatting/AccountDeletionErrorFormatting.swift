//
//  AccountDeletionErrorFormatting.swift
//  Fitness Coach
//
//  Forma — Safe user-facing error messages for account deletion UI.
//

import Foundation

enum AccountDeletionErrorFormatting {

    /// Returns a privacy-safe message suitable for UI. Never surfaces raw backend or Firebase errors.
    static func userFacingMessage(for summary: AccountDeletionSummary) -> String? {
        if summary.isSuccessful {
            return nil
        }

        if let message = summary.userFacingMessage?.trimmingCharacters(in: .whitespacesAndNewlines),
           !message.isEmpty,
           isSafeUserFacingMessage(message) {
            return message
        }

        switch summary.failureCategory {
        case .offline:
            return FormaProductCopy.Settings.PrivacyData.deletionOfflineErrorMessage
        case .permissionDenied:
            return FormaProductCopy.Settings.PrivacyData.deletionPermissionDeniedErrorMessage
        case .unauthenticated:
            return FormaProductCopy.Settings.PrivacyData.deletionFlowUnavailableMessage
        case .reauthenticationRequired:
            return FormaProductCopy.Settings.PrivacyData.deletionReauthenticationMessage
        case .remoteDataDeleteFailed, .authDeleteFailed, .localWipeFailed,
             .accountSwitched, .unknown, .none:
            return FormaProductCopy.Settings.PrivacyData.deletionGenericErrorMessage
        }
    }

    private static func isSafeUserFacingMessage(_ message: String) -> Bool {
        let lowered = message.lowercased()
        let blockedTerms = [
            "firebase",
            "firestore",
            "grpc",
            "http",
            "nserror",
            "exception",
            "stack",
            "token",
            "uid:",
            "permission_denied",
            "unauthenticated"
        ]
        return !blockedTerms.contains(where: { lowered.contains($0) })
    }
}
