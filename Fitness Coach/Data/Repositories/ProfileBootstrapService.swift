//
//  ProfileBootstrapService.swift
//  Fitness Coach
//
//  FitPilot — Local profile check with optional cloud restore on sign-in.
//

import Foundation

enum ProfileBootstrapResult: Equatable {
    case main
    /// Signed-in user with no local profile and no cloud snapshot (confirmed absent).
    case missingCloudProfile
}

@MainActor
final class ProfileBootstrapService {

    private let userProfileService: UserProfileService
    private let cloudStore: CloudUserProfileStoring
    private let cloudSyncStore: ProfileCloudSyncStore?

    init(
        userProfileService: UserProfileService,
        cloudStore: CloudUserProfileStoring,
        cloudSyncStore: ProfileCloudSyncStore? = nil
    ) {
        self.userProfileService = userProfileService
        self.cloudStore = cloudStore
        self.cloudSyncStore = cloudSyncStore
    }

    /// Synchronous local profile presence check for pre-auth shell routing.
    func hasLocalProfile() -> Bool {
        (try? userProfileService.getCurrentProfile()) != nil
    }

    func currentProfile() throws -> UserProfile? {
        try userProfileService.getCurrentProfile()
    }

    func assignProfileOwner(uid: String) throws -> UserProfile {
        try userProfileService.assignOwnerUID(uid)
    }

    func resolve(uid: String) async throws -> ProfileBootstrapResult {
        ProfileBootstrapDebugLogger.event("profile_bootstrap_started", fields: ["uid": uid])
        ProfileBootstrapDebugLogger.event("Resolving profile route", fields: ["uid": uid])

        if let profile = try userProfileService.getCurrentProfile(),
           profile.ownerUID == uid {
            ProfileBootstrapDebugLogger.event(
                "local_profile_found",
                fields: ["uid": uid, "route": "main", "reason": "ownerMatches"]
            )
            return .main
        }

        if try userProfileService.getCurrentProfile() != nil {
            ProfileBootstrapDebugLogger.event(
                "local_profile_found",
                fields: ["uid": uid, "route": "ownershipResolutionRequired"]
            )
            throw ServiceError.invalidInput(
                "Local profile requires ownership resolution before bootstrap restore."
            )
        }

        ProfileBootstrapDebugLogger.event("local_profile_missing", fields: ["uid": uid])

        switch await resolveCloudProfile(uid: uid, context: .bootstrap) {
        case .found(let cloudDocument):
            ProfileBootstrapDebugLogger.event(
                "cloud_profile_restore_started",
                fields: ["uid": uid]
            )

            _ = try userProfileService.restoreProfile(from: cloudDocument, ownerUID: uid)

            cloudSyncStore?.markSynced(uid: uid, updatedAt: cloudDocument.updatedAt)

            ProfileBootstrapDebugLogger.event(
                "cloud_profile_restore_completed",
                fields: ["uid": uid, "route": "main"]
            )
            return .main
        case .missing:
            ProfileBootstrapDebugLogger.event(
                "cloud_profile_missing",
                fields: ["uid": uid, "route": "missingCloudProfile"]
            )
            return .missingCloudProfile
        case .failed(let failure):
            throw failure
        }
    }

    /// Read-only cloud profile resolution for ownership and bootstrap decisions.
    /// Never writes to Firestore.
    func resolveCloudProfile(
        uid: String,
        context: CloudProfileLookupContext
    ) async -> CloudProfileResolutionResult {
        ProfileBootstrapDebugLogger.event(
            "cloud_profile_lookup_started",
            fields: ["uid": uid, "context": context.rawValue]
        )

        do {
            guard let cloudDocument = try await cloudStore.fetch(uid: uid) else {
                ProfileBootstrapDebugLogger.event(
                    "cloud_profile_missing",
                    fields: ["uid": uid, "context": context.rawValue]
                )
                return .missing
            }

            ProfileBootstrapDebugLogger.event(
                "cloud_profile_found",
                fields: [
                    "uid": uid,
                    "context": context.rawValue,
                    "updatedAt": ISO8601DateFormatter().string(from: cloudDocument.updatedAt)
                ]
            )
            return .found(cloudDocument)
        } catch {
            let failure = CloudProfileResolutionFailure(error)
            ProfileBootstrapDebugLogger.error(
                "cloud_profile_lookup_failed",
                fields: ["uid": uid, "context": context.rawValue],
                underlying: error
            )
            return .failed(failure)
        }
    }

    /// Ownership-policy adapter over `resolveCloudProfile`.
    func ownershipCloudLookup(
        uid: String,
        context: CloudProfileLookupContext
    ) async -> CloudProfileLookupResult {
        await resolveCloudProfile(uid: uid, context: context).ownershipLookupResult
    }

    func linkLocalProfileToAccount(uid: String) throws -> UserProfile {
        try userProfileService.assignOwnerUID(uid)
    }

    func adoptCloudProfile(_ document: CloudUserProfileDocument, uid: String) throws -> UserProfile {
        let profile = try userProfileService.replaceLocalProfile(with: document, ownerUID: uid)
        cloudSyncStore?.markSynced(uid: uid, updatedAt: document.updatedAt)
        return profile
    }

    func saveProfileToCloud(uid: String, intent: CloudProfileWriteIntent) async throws {
        try await validateCloudWrite(uid: uid, intent: intent)

        guard let profile = try userProfileService.getCurrentProfile() else {
            throw ServiceError.missingUserProfile
        }

        ProfileBootstrapDebugLogger.event(
            "Uploading local profile",
            fields: ["uid": uid, "intent": intent.logLabel]
        )
        try await cloudStore.save(profile: profile, uid: uid)
    }

    /// Uploads a locally committed profile after explicit write authorization.
    func syncOnboardingProfileToCloud(uid: String, intent: CloudProfileWriteIntent) async throws {
        try await saveProfileToCloud(uid: uid, intent: intent)
        try await verifyCloudProfileSaved(uid: uid)
    }

    private func validateCloudWrite(uid: String, intent: CloudProfileWriteIntent) async throws {
        guard let profile = try userProfileService.getCurrentProfile() else {
            throw ServiceError.missingUserProfile
        }

        switch intent {
        case .ownedProfileUpdate:
            guard profile.ownerUID == uid else {
                let reason = CloudProfileWriteBlockedReason.ownerMismatch(
                    localOwnerUID: profile.ownerUID,
                    signedInUID: uid
                )
                logBlockedWrite(uid: uid, intent: intent, reason: reason)
                throw CloudProfileWriteError.blocked(reason)
            }

        case .newProfileInitialUpload:
            if let localOwnerUID = profile.ownerUID, localOwnerUID != uid {
                let reason = CloudProfileWriteBlockedReason.ownerMismatch(
                    localOwnerUID: localOwnerUID,
                    signedInUID: uid
                )
                logBlockedWrite(uid: uid, intent: intent, reason: reason)
                throw CloudProfileWriteError.blocked(reason)
            }

            switch await resolveCloudProfile(uid: uid, context: .profileUpload) {
            case .found:
                let reason = CloudProfileWriteBlockedReason.cloudProfileExists
                logBlockedWrite(uid: uid, intent: intent, reason: reason)
                throw CloudProfileWriteError.blocked(reason)
            case .failed:
                let reason = CloudProfileWriteBlockedReason.cloudLookupFailed
                logBlockedWrite(uid: uid, intent: intent, reason: reason)
                throw CloudProfileWriteError.blocked(reason)
            case .missing:
                break
            }

        case .userConfirmedReplace:
            break
        }
    }

    private func logBlockedWrite(
        uid: String,
        intent: CloudProfileWriteIntent,
        reason: CloudProfileWriteBlockedReason
    ) {
        ProfileBootstrapDebugLogger.event(
            "cloud_profile_write_blocked",
            fields: [
                "uid": uid,
                "intent": intent.logLabel,
                "reason": String(describing: reason)
            ]
        )
    }

    private func verifyCloudProfileSaved(uid: String) async throws {
        guard let cloudDocument = try await cloudStore.fetch(uid: uid) else {
            throw ServiceError.invalidInput("Cloud profile verification failed after upload.")
        }
        ProfileBootstrapDebugLogger.event(
            "Cloud profile upload verified",
            fields: [
                "uid": uid,
                "updatedAt": ISO8601DateFormatter().string(from: cloudDocument.updatedAt)
            ]
        )
    }

    /// Probes Firestore for an existing profile without treating fetch errors as absence.
    func fetchCloudProfilePresence(uid: String) async throws -> CloudProfilePresence {
        switch await resolveCloudProfile(uid: uid, context: .onboardingCompletion) {
        case .found(let cloudDocument):
            return .present(cloudDocument)
        case .missing:
            ProfileBootstrapDebugLogger.event(
                "No cloud profile for onboarding completion",
                fields: ["uid": uid]
            )
            return .absent
        case .failed(let failure):
            throw failure
        }
    }
}
