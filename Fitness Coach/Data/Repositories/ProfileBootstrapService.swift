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

    init(
        userProfileService: UserProfileService,
        cloudStore: CloudUserProfileStoring
    ) {
        self.userProfileService = userProfileService
        self.cloudStore = cloudStore
    }

    func resolve(uid: String) async throws -> ProfileBootstrapResult {
        ProfileBootstrapDebugLogger.event("Resolving profile route", fields: ["uid": uid])

        if hasLocalProfile() {
            ProfileBootstrapDebugLogger.event("Local profile found", fields: ["uid": uid, "route": "main"])
            return .main
        }

        ProfileBootstrapDebugLogger.event("No local profile; checking cloud", fields: ["uid": uid])

        guard let cloudDocument = try await cloudStore.fetch(uid: uid) else {
            ProfileBootstrapDebugLogger.event(
                "No cloud profile",
                fields: ["uid": uid, "route": "missingCloudProfile"]
            )
            return .missingCloudProfile
        }

        _ = try userProfileService.restoreProfile(from: cloudDocument)
        ProfileBootstrapDebugLogger.event("Restored cloud profile locally", fields: ["uid": uid, "route": "main"])
        return .main
    }

    /// Synchronous local profile presence check for pre-auth shell routing.
    func hasLocalProfile() -> Bool {
        (try? userProfileService.getCurrentProfile()) != nil
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
