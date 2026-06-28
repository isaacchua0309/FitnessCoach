//
//  ProfileBootstrapCoordinator.swift
//  Fitness Coach
//
//  Forma — Testable signed-in profile bootstrap and cloud sync orchestration.
//

import Foundation

enum ProfileBootstrapPhase: Equatable, Sendable {
    case idle
    case loadingLocal
    case waitingForAuth
    case checkingCloud(redactedUID: String)
    case restoringCloud(redactedUID: String)
    case uploadingCloud(redactedUID: String)
    case localProfileReady
    case cloudProfileReady
    case needsOnboardingAfterCloudMiss
    case awaitingCloudSync
    case failed(message: String)
}

enum SignedInProfileReconcileDecision: Equatable, Sendable {
    /// Onboarding save-plan sign-in: probe cloud then upload or conflict.
    case resolveOnboardingCompletion(uid: String)
    /// Local profile ownership matches the signed-in UID.
    case routeToMain
    /// Upload local profile after ownership resolution allows linking.
    case syncLocalProfileToCloud(uid: String)
    /// No local profile: fetch cloud and restore or route to missing-cloud flow.
    case loadCloudProfile(uid: String)
    /// Unowned or uncertain local profile needs read-only cloud lookup first.
    case requireOwnershipCloudLookup(uid: String)
    /// Local profile belongs to a different Firebase account.
    case showAccountMismatch(uid: String)
    /// Local and cloud profiles both exist; user must choose.
    case showProfileConflict(uid: String)
    /// Cloud fetch failed during ownership resolution.
    case showCloudFetchFailed(uid: String)
    /// Confirmed no cloud profile for a user without local data.
    case presentMissingCloudProfile(uid: String)
    /// No bootstrap action required for the current root/auth combination.
    case skip
}

struct SignedInProfileReconcileInput: Equatable, Sendable {
    var uid: String
    var pendingOnboardingCompletion: Bool
    var pendingExistingUserSignIn: Bool
    var hasLocalProfile: Bool
    var localOwnerUID: String?
    var isFreshSignIn: Bool
    var rootState: RootViewState
    /// Transitional hint only — not used as proof when `localOwnerUID` is set.
    var isSyncedForCurrentUID: Bool
    /// Populated after `requireOwnershipCloudLookup` completes.
    var cloudResult: CloudProfileLookupResult?
}

enum OnboardingCompletionOutcome: Equatable, Sendable {
    case uploadedToCloud
    case cloudProfileConflict(CloudUserProfileDocument)
    case cloudCheckFailed
    case cloudSyncFailed
}

enum ProfileBootstrapCoordinator {

    static func reconcileDecision(_ input: SignedInProfileReconcileInput) -> SignedInProfileReconcileDecision {
        ProfileBootstrapDebugLogger.event(
            "route_decision",
            fields: [
                "uid": input.uid,
                "hasLocalProfile": String(input.hasLocalProfile),
                "localOwnerUID": input.localOwnerUID ?? "nil",
                "pendingOnboardingCompletion": String(input.pendingOnboardingCompletion),
                "isFreshSignIn": String(input.isFreshSignIn),
                "isSyncedForCurrentUID": String(input.isSyncedForCurrentUID),
                "cloudResult": input.cloudResult.map(String.init(describing:)) ?? "pending",
                "rootState": String(describing: input.rootState)
            ]
        )

        let outcome = ProfileOwnershipResolver.resolve(input.ownershipInput)
        return mapOwnershipOutcome(outcome, input: input)
    }

    static func bootstrapPhase(for rootState: RootViewState, uid: String?) -> ProfileBootstrapPhase {
        let redacted = uid.map(ProfileBootstrapDebugLogger.redactedUID) ?? "none"
        switch rootState {
        case .loading:
            return .checkingCloud(redactedUID: redacted)
        case .missingCloudProfile:
            return .needsOnboardingAfterCloudMiss
        case .onboardingCloudProfileConflict, .onboardingCloudCheckFailed, .existingUserProfileLookupFailed,
             .cloudProfileUploadFailed, .accountProfileMismatch:
            return .checkingCloud(redactedUID: redacted)
        case .onboarding:
            return .needsOnboardingAfterCloudMiss
        case .main:
            return .cloudProfileReady
        case .error(let message):
            return .failed(message: message)
        }
    }
}

@MainActor
final class ProfileBootstrapCoordinatorService {

    private let profileBootstrapService: ProfileBootstrapService
    private let cloudSyncStore: ProfileCloudSyncStore

    init(
        profileBootstrapService: ProfileBootstrapService,
        cloudSyncStore: ProfileCloudSyncStore
    ) {
        self.profileBootstrapService = profileBootstrapService
        self.cloudSyncStore = cloudSyncStore
    }

    func reconcileDecision(
        uid: String,
        pendingOnboardingCompletion: Bool,
        pendingExistingUserSignIn: Bool = false,
        isFreshSignIn: Bool,
        rootState: RootViewState,
        cloudResult: CloudProfileLookupResult? = nil
    ) -> SignedInProfileReconcileDecision {
        let localOwnerUID = try? profileBootstrapService.currentProfile()?.ownerUID
        return ProfileBootstrapCoordinator.reconcileDecision(
            SignedInProfileReconcileInput(
                uid: uid,
                pendingOnboardingCompletion: pendingOnboardingCompletion,
                pendingExistingUserSignIn: pendingExistingUserSignIn,
                hasLocalProfile: profileBootstrapService.hasLocalProfile(),
                localOwnerUID: localOwnerUID,
                isFreshSignIn: isFreshSignIn,
                rootState: rootState,
                isSyncedForCurrentUID: cloudSyncStore.isSyncedForUID(uid),
                cloudResult: cloudResult
            )
        )
    }

    func ownershipCloudLookup(
        uid: String,
        context: CloudProfileLookupContext
    ) async -> CloudProfileLookupResult {
        await profileBootstrapService.ownershipCloudLookup(uid: uid, context: context)
    }

    func syncOnboardingProfileToCloud(
        uid: String,
        intent: CloudProfileWriteIntent = .newProfileInitialUpload
    ) async throws {
        ProfileBootstrapDebugLogger.event(
            "onboarding_cloud_sync_started",
            fields: ["uid": uid, "intent": intent.logLabel]
        )

        try await profileBootstrapService.syncOnboardingProfileToCloud(uid: uid, intent: intent)
        try finalizeAfterCloudUpload(uid: uid)

        ProfileBootstrapDebugLogger.event(
            "onboarding_cloud_sync_completed",
            fields: ["uid": uid, "intent": intent.logLabel]
        )
    }

    func syncLocalProfileToCloud(uid: String) async throws {
        try await syncOnboardingProfileToCloud(uid: uid, intent: .newProfileInitialUpload)
    }

    private func finalizeAfterCloudUpload(uid: String) throws {
        if let profile = try profileBootstrapService.currentProfile() {
            cloudSyncStore.markSynced(uid: uid, updatedAt: profile.updatedAt)
        }
        _ = try profileBootstrapService.assignProfileOwner(uid: uid)
    }

    func markSyncedFromCloudRestore(uid: String, updatedAt: Date) {
        cloudSyncStore.markSynced(uid: uid, updatedAt: updatedAt)
    }

    func isSyncedForUID(_ uid: String) -> Bool {
        cloudSyncStore.isSyncedForUID(uid)
    }

    func resolveOnboardingCompletion(uid: String) async -> OnboardingCompletionOutcome {
        ProfileBootstrapDebugLogger.event(
            "cloud_profile_lookup_started",
            fields: ["uid": uid, "context": "onboardingCompletion"]
        )

        let resolution = await profileBootstrapService.resolveCloudProfile(
            uid: uid,
            context: .onboardingCompletion
        )

        switch resolution {
        case .missing:
            ProfileBootstrapDebugLogger.event(
                "cloud_profile_missing",
                fields: ["uid": uid, "context": "onboardingCompletion"]
            )
            do {
                try await syncOnboardingProfileToCloud(uid: uid)
                return .uploadedToCloud
            } catch {
                ProfileBootstrapDebugLogger.error(
                    "onboarding_cloud_sync_failed",
                    fields: ["uid": uid],
                    underlying: error
                )
                return .cloudSyncFailed
            }
        case .found(let document):
            ProfileBootstrapDebugLogger.event(
                "cloud_profile_found",
                fields: ["uid": uid, "context": "onboardingCompletion"]
            )
            return .cloudProfileConflict(document)
        case .failed(let failure):
            ProfileBootstrapDebugLogger.error(
                "cloud_profile_lookup_failed",
                fields: ["uid": uid, "context": "onboardingCompletion"],
                underlying: failure
            )
            return .cloudCheckFailed
        }
    }

    func restoreGoogleAccountPlan(uid: String) async -> AccountMismatchRestoreOutcome {
        ProfileBootstrapDebugLogger.event(
            "account_mismatch_restore_started",
            fields: ["uid": uid]
        )

        switch await profileBootstrapService.resolveCloudProfile(uid: uid, context: .accountSwitch) {
        case .found(let document):
            do {
                _ = try profileBootstrapService.adoptCloudProfile(document, uid: uid)
                ProfileBootstrapDebugLogger.event(
                    "account_mismatch_restore_completed",
                    fields: ["uid": uid]
                )
                return .restoredToMain
            } catch {
                ProfileBootstrapDebugLogger.error(
                    "account_mismatch_restore_failed",
                    fields: ["uid": uid],
                    underlying: error
                )
                return .cloudFetchFailed
            }
        case .missing:
            ProfileBootstrapDebugLogger.event(
                "account_mismatch_restore_missing_cloud",
                fields: ["uid": uid]
            )
            return .missingCloudProfile
        case .failed(let failure):
            ProfileBootstrapDebugLogger.error(
                "account_mismatch_restore_lookup_failed",
                fields: ["uid": uid],
                underlying: failure
            )
            return .cloudFetchFailed
        }
    }

    func prepareUseDeviceProfile(uid: String) async -> AccountMismatchUseDeviceOutcome {
        ProfileBootstrapDebugLogger.event(
            "account_mismatch_use_device_started",
            fields: ["uid": uid]
        )

        switch await profileBootstrapService.resolveCloudProfile(uid: uid, context: .accountSwitch) {
        case .found(let document):
            ProfileBootstrapDebugLogger.event(
                "account_mismatch_use_device_conflict",
                fields: ["uid": uid]
            )
            return .cloudProfileConflict(document)
        case .missing:
            ProfileBootstrapDebugLogger.event(
                "account_mismatch_use_device_confirmation_required",
                fields: ["uid": uid]
            )
            return .requiresLocalLinkConfirmation
        case .failed(let failure):
            ProfileBootstrapDebugLogger.error(
                "account_mismatch_use_device_lookup_failed",
                fields: ["uid": uid],
                underlying: failure
            )
            return .cloudFetchFailed
        }
    }

    func confirmLinkLocalProfileToAccount(uid: String) throws -> UserProfile {
        let profile = try profileBootstrapService.linkLocalProfileToAccount(uid: uid)
        ProfileBootstrapDebugLogger.event(
            "account_mismatch_use_device_linked_local_only",
            fields: ["uid": uid]
        )
        return profile
    }

    func restoreExistingPlanAfterConflict(
        uid: String,
        cloudDocument: CloudUserProfileDocument
    ) throws -> UserProfile {
        let profile = try profileBootstrapService.adoptCloudProfile(cloudDocument, uid: uid)
        ProfileBootstrapDebugLogger.event(
            "profile_conflict_restore_completed",
            fields: ["uid": uid]
        )
        return profile
    }

    func uploadDevicePlanAfterConflict(uid: String) async throws {
        ProfileBootstrapDebugLogger.event(
            "profile_conflict_upload_started",
            fields: ["uid": uid]
        )
        try await syncOnboardingProfileToCloud(uid: uid, intent: .userConfirmedReplace)
        ProfileBootstrapDebugLogger.event(
            "profile_conflict_upload_completed",
            fields: ["uid": uid]
        )
    }

  /// Returning-member sign-in: probe ownership/cloud and restore without creating profiles.
    func resolveExistingUserSignIn(
        uid: String,
        isFreshSignIn: Bool,
        rootState: RootViewState
    ) async -> ExistingUserSignInServiceOutcome {
        var cloudResult: CloudProfileLookupResult?

        for _ in 0..<4 {
            let decision = reconcileDecision(
                uid: uid,
                pendingOnboardingCompletion: false,
                pendingExistingUserSignIn: true,
                isFreshSignIn: isFreshSignIn,
                rootState: rootState,
                cloudResult: cloudResult
            )

            switch decision {
            case .routeToMain:
                return .resolution(.profileFound(.localOwned))

            case .loadCloudProfile:
                do {
                    let bootstrapResult = try await profileBootstrapService.resolve(uid: uid)
                    return .resolution(
                        ExistingUserSignInResolutionMapper.fromBootstrapResult(bootstrapResult)
                    )
                } catch {
                    ProfileBootstrapDebugLogger.error(
                        "existing_user_sign_in_bootstrap_failed",
                        fields: ["uid": uid],
                        underlying: error
                    )
                    return .resolution(.lookupFailed)
                }

            case .requireOwnershipCloudLookup:
                cloudResult = await ownershipCloudLookup(
                    uid: uid,
                    context: .ownershipResolution
                )
                continue

            case .presentMissingCloudProfile:
                return .resolution(.noProfileFound)

            case .showCloudFetchFailed:
                return .resolution(.lookupFailed)

            case .showProfileConflict:
                return .resolution(.conflict)

            case .showAccountMismatch:
                return .accountMismatch

            case .resolveOnboardingCompletion, .syncLocalProfileToCloud, .skip:
                ProfileBootstrapDebugLogger.event(
                    "existing_user_sign_in_unexpected_decision",
                    fields: ["uid": uid, "decision": String(describing: decision)]
                )
                return .resolution(.lookupFailed)
            }
        }

        return .resolution(.lookupFailed)
    }

    func retryCloudProfileUpload(
        uid: String,
        context: CloudProfileUploadFailureContext
    ) async throws {
        ProfileBootstrapDebugLogger.event(
            "cloud_profile_upload_retry_started",
            fields: ["uid": uid, "context": String(describing: context)]
        )

        switch context {
        case .onboardingCompletion, .reconcileUpload:
            try await syncOnboardingProfileToCloud(uid: uid, intent: .newProfileInitialUpload)
        case .conflictReplace:
            try await syncOnboardingProfileToCloud(uid: uid, intent: .userConfirmedReplace)
        case .profileEdit:
            try await profileBootstrapService.saveProfileToCloud(
                uid: uid,
                intent: .ownedProfileUpdate
            )
            if let profile = try profileBootstrapService.currentProfile() {
                cloudSyncStore.markSynced(uid: uid, updatedAt: profile.updatedAt)
            }
        }

        ProfileBootstrapDebugLogger.event(
            "cloud_profile_upload_retry_completed",
            fields: ["uid": uid, "context": String(describing: context)]
        )
    }
}
