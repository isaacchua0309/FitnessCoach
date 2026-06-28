//
//  ExistingUserSignInResolutionResult.swift
//  Fitness Coach
//
//  Forma — Typed outcomes for returning-member profile resolution.
//

import Foundation

enum ExistingUserProfileSource: Equatable, Sendable {
    case cloudRestored
    case localOwned
}

enum ExistingUserSignInResolutionResult: Equatable, Sendable {
    case profileFound(ExistingUserProfileSource)
    case noProfileFound
    case lookupFailed
    case conflict
}

enum ExistingUserSignInServiceOutcome: Equatable, Sendable {
    case resolution(ExistingUserSignInResolutionResult)
    case accountMismatch
}

enum ExistingUserSignInResolutionMapper {

    static func fromReconcileDecision(
        _ decision: SignedInProfileReconcileDecision
    ) -> ExistingUserSignInResolutionResult? {
        switch decision {
        case .routeToMain:
            return .profileFound(.localOwned)
        case .presentMissingCloudProfile:
            return .noProfileFound
        case .showCloudFetchFailed:
            return .lookupFailed
        case .showProfileConflict:
            return .conflict
        case .loadCloudProfile, .requireOwnershipCloudLookup, .resolveOnboardingCompletion,
             .syncLocalProfileToCloud, .showAccountMismatch, .skip:
            return nil
        }
    }

    static func fromBootstrapResult(
        _ result: ProfileBootstrapResult
    ) -> ExistingUserSignInResolutionResult {
        switch result {
        case .main:
            return .profileFound(.cloudRestored)
        case .missingCloudProfile:
            return .noProfileFound
        }
    }
}

enum OnboardingDraftPolicy {

    /// Stale pre-auth onboarding drafts should not resume after a returning user restores a profile.
    static func shouldClearStaleDraftAfterExistingUserRestore(hasPersistedDraft: Bool) -> Bool {
        hasPersistedDraft
    }
}
