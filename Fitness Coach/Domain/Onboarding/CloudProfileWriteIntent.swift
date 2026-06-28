//
//  CloudProfileWriteIntent.swift
//  Fitness Coach
//
//  Forma — Explicit authorization for Firestore profile writes (Stage 7).
//

import Foundation

/// Declares why a cloud profile write is being attempted. Guards must not infer destructive intent.
enum CloudProfileWriteIntent: Equatable, Sendable {
    /// Same-account plan edit or background refresh; local `ownerUID` must match.
    case ownedProfileUpdate
    /// First upload after cloud was confirmed absent (onboarding completion, reconcile upload).
    case newProfileInitialUpload
    /// User explicitly chose to replace the saved cloud plan with the device plan.
    case userConfirmedReplace
}

enum CloudProfileWriteBlockedReason: Sendable {
    case ownerMismatch(localOwnerUID: String?, signedInUID: String)
    case cloudProfileExists
    case cloudLookupFailed
}

extension CloudProfileWriteBlockedReason: Equatable {
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case let (.ownerMismatch(localL, signedL), .ownerMismatch(localR, signedR)):
            return localL == localR && signedL == signedR
        case (.cloudProfileExists, .cloudProfileExists):
            return true
        case (.cloudLookupFailed, .cloudLookupFailed):
            return true
        default:
            return false
        }
    }
}

enum CloudProfileWriteError: Error, Sendable {
    case blocked(CloudProfileWriteBlockedReason)
}

extension CloudProfileWriteError: Equatable {
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case let (.blocked(lhsReason), .blocked(rhsReason)):
            return lhsReason == rhsReason
        }
    }
}

extension CloudProfileWriteIntent {
    var logLabel: String {
        switch self {
        case .ownedProfileUpdate: return "ownedProfileUpdate"
        case .newProfileInitialUpload: return "newProfileInitialUpload"
        case .userConfirmedReplace: return "userConfirmedReplace"
        }
    }
}
