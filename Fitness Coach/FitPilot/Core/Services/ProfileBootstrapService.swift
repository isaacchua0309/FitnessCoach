//
//  ProfileBootstrapService.swift
//  Fitness Coach
//
//  FitPilot — Local profile check with optional cloud restore on sign-in.
//

import Foundation

enum ProfileBootstrapResult: Equatable {
    case main
    case onboarding
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

        if try userProfileService.getCurrentProfile() != nil {
            ProfileBootstrapDebugLogger.event("Local profile found", fields: ["uid": uid, "route": "main"])
            return .main
        }

        ProfileBootstrapDebugLogger.event("No local profile; checking cloud", fields: ["uid": uid])

        guard let cloudDocument = try await cloudStore.fetch(uid: uid) else {
            ProfileBootstrapDebugLogger.event("No cloud profile", fields: ["uid": uid, "route": "onboarding"])
            return .onboarding
        }

        _ = try userProfileService.restoreProfile(from: cloudDocument)
        ProfileBootstrapDebugLogger.event("Restored cloud profile locally", fields: ["uid": uid, "route": "main"])
        return .main
    }

    func saveProfileToCloud(uid: String) async throws {
        guard let profile = try userProfileService.getCurrentProfile() else {
            throw ServiceError.missingUserProfile
        }

        ProfileBootstrapDebugLogger.event("Uploading local profile", fields: ["uid": uid])
        try await cloudStore.save(profile: profile, uid: uid)
    }
}
