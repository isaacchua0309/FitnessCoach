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

enum CloudProfileWriteBlockedReason: Equatable, Sendable {
    case ownerMismatch(localOwnerUID: String?, signedInUID: String)
    case cloudProfileExists
    case cloudLookupFailed
}

enum CloudProfileWriteError: Error, Equatable {
    case blocked(CloudProfileWriteBlockedReason)
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
