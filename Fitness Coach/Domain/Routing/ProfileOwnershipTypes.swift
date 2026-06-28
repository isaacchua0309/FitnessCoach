//
//  ProfileOwnershipTypes.swift
//  Fitness Coach
//
//  Forma — Pure inputs and outcomes for signed-in profile ownership resolution.
//

import Foundation

/// Lightweight cloud snapshot metadata for routing decisions (no Firestore types).
struct CloudProfileSummary: Equatable, Sendable {
    var updatedAt: Date
}

enum CloudProfileLookupResult: Equatable, Sendable {
    case found(CloudProfileSummary)
    case missing
    case failed
}

enum SignInContext: Equatable, Sendable {
    case normalLaunch
    case returningUser
    case onboardingCompletion
    case accountSwitch
}

struct ProfileOwnershipInput: Equatable, Sendable {
    var signedInUID: String
    var hasLocalProfile: Bool
    var localOwnerUID: String?
    /// Save-plan sign-in still resolving cloud presence before broader reconcile.
    var hasLocalProfilePendingOnboardingCompletion: Bool
    /// `nil` when cloud lookup has not completed yet.
    var cloudResult: CloudProfileLookupResult?
    var signInContext: SignInContext
    /// Transitional hint from `ProfileCloudSyncStore`; not proof of ownership.
    var isSyncedForCurrentUID: Bool
}

enum ProfileOwnershipOutcome: Equatable, Sendable {
    case useLocalProfile
    case restoreCloudProfile
    case showMissingCloudProfile
    case showCloudFetchFailed
    case showAccountMismatch
    case showProfileConflict
    case uploadLocalProfile
    case requireCloudLookup
}
