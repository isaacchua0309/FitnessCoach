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

    func resolve(uid: String) async throws -> ProfileBootstrapResult {
        ProfileBootstrapDebugLogger.event("profile_bootstrap_started", fields: ["uid": uid])
        ProfileBootstrapDebugLogger.event("Resolving profile route", fields: ["uid": uid])

        if hasLocalProfile() {
            ProfileBootstrapDebugLogger.event("local_profile_found", fields: ["uid": uid, "route": "main"])
            return .main
        }

        ProfileBootstrapDebugLogger.event("local_profile_missing", fields: ["uid": uid])
        ProfileBootstrapDebugLogger.event(
            "cloud_profile_lookup_started",
            fields: ["uid": uid, "context": "bootstrap"]
        )

        guard let cloudDocument = try await cloudStore.fetch(uid: uid) else {
            ProfileBootstrapDebugLogger.event(
                "cloud_profile_missing",
                fields: ["uid": uid, "route": "missingCloudProfile"]
            )
            return .missingCloudProfile
        }

        ProfileBootstrapDebugLogger.event(
            "cloud_profile_found",
            fields: ["uid": uid, "context": "bootstrap"]
        )
        ProfileBootstrapDebugLogger.event(
            "cloud_profile_restore_started",
            fields: ["uid": uid]
        )

        _ = try userProfileService.restoreProfile(from: cloudDocument)

        cloudSyncStore?.markSynced(uid: uid, updatedAt: cloudDocument.updatedAt)

        ProfileBootstrapDebugLogger.event(
            "cloud_profile_restore_completed",
            fields: ["uid": uid, "route": "main"]
        )
        return .main
    }

    func saveProfileToCloud(uid: String) async throws {
        guard let profile = try userProfileService.getCurrentProfile() else {
            throw ServiceError.missingUserProfile
        }

        ProfileBootstrapDebugLogger.event("Uploading local profile", fields: ["uid": uid])
        try await cloudStore.save(profile: profile, uid: uid)
    }

    /// Uploads a locally committed onboarding profile after Google sign-in.
    func syncOnboardingProfileToCloud(uid: String) async throws {
        try await saveProfileToCloud(uid: uid)
        try await verifyCloudProfileSaved(uid: uid)
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
        ProfileBootstrapDebugLogger.event(
            "Probing cloud profile for onboarding completion",
            fields: ["uid": uid]
        )

        guard let cloudDocument = try await cloudStore.fetch(uid: uid) else {
            ProfileBootstrapDebugLogger.event(
                "No cloud profile for onboarding completion",
                fields: ["uid": uid]
            )
            return .absent
        }

        ProfileBootstrapDebugLogger.event(
            "Cloud profile found for onboarding completion",
            fields: ["uid": uid]
        )
        return .present(cloudDocument)
    }
}
