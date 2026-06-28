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
    /// Local profile already synced for this UID.
    case routeToMain
    /// Local profile exists but has not been confirmed for this UID.
    case syncLocalProfileToCloud(uid: String)
    /// No local profile: fetch cloud and restore or route to missing-cloud flow.
    case loadCloudProfile(uid: String)
    /// No bootstrap action required for the current root/auth combination.
    case skip
}

struct SignedInProfileReconcileInput: Equatable, Sendable {
    var uid: String
    var pendingOnboardingCompletion: Bool
    var hasLocalProfile: Bool
    var isFreshSignIn: Bool
    var rootState: RootViewState
    var isSyncedForCurrentUID: Bool
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
                "pendingOnboardingCompletion": String(input.pendingOnboardingCompletion),
                "isFreshSignIn": String(input.isFreshSignIn),
                "isSyncedForCurrentUID": String(input.isSyncedForCurrentUID),
                "rootState": String(describing: input.rootState)
            ]
        )

        if AuthGateRoutingPolicy.shouldDeferLocalProfileShortCircuit(
            pendingOnboardingCompletion: input.pendingOnboardingCompletion,
            hasLocalProfile: input.hasLocalProfile
        ) {
            return .resolveOnboardingCompletion(uid: input.uid)
        }

        if input.hasLocalProfile {
            if input.isSyncedForCurrentUID {
                ProfileBootstrapDebugLogger.event(
                    "local_profile_found",
                    fields: ["uid": input.uid, "route": "main"]
                )
                return .routeToMain
            }

            ProfileBootstrapDebugLogger.event(
                "local_profile_found",
                fields: ["uid": input.uid, "route": "syncRequired"]
            )
            return .syncLocalProfileToCloud(uid: input.uid)
        }

        ProfileBootstrapDebugLogger.event(
            "local_profile_missing",
            fields: ["uid": input.uid]
        )

        let shouldLoadCloudProfile = AuthGateRoutingPolicy.shouldReloadSignedInCloudProfile(
            isFreshSignIn: input.isFreshSignIn,
            rootState: input.rootState,
            hasLocalProfile: input.hasLocalProfile
        )

        guard shouldLoadCloudProfile else { return .skip }

        return .loadCloudProfile(uid: input.uid)
    }

    static func bootstrapPhase(for rootState: RootViewState, uid: String?) -> ProfileBootstrapPhase {
        let redacted = uid.map(ProfileBootstrapDebugLogger.redactedUID) ?? "none"
        switch rootState {
        case .loading:
            return .checkingCloud(redactedUID: redacted)
        case .missingCloudProfile:
            return .needsOnboardingAfterCloudMiss
        case .onboardingCloudProfileConflict, .onboardingCloudCheckFailed:
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
        isFreshSignIn: Bool,
        rootState: RootViewState
    ) -> SignedInProfileReconcileDecision {
        ProfileBootstrapCoordinator.reconcileDecision(
            SignedInProfileReconcileInput(
                uid: uid,
                pendingOnboardingCompletion: pendingOnboardingCompletion,
                hasLocalProfile: profileBootstrapService.hasLocalProfile(),
                isFreshSignIn: isFreshSignIn,
                rootState: rootState,
                isSyncedForCurrentUID: cloudSyncStore.isSyncedForUID(uid)
            )
        )
    }

    func syncOnboardingProfileToCloud(uid: String) async throws {
        ProfileBootstrapDebugLogger.event(
            "onboarding_cloud_sync_started",
            fields: ["uid": uid]
        )

        try await profileBootstrapService.syncOnboardingProfileToCloud(uid: uid)

        if let profile = try profileBootstrapService.currentProfile() {
            cloudSyncStore.markSynced(uid: uid, updatedAt: profile.updatedAt)
        }

        ProfileBootstrapDebugLogger.event(
            "onboarding_cloud_sync_completed",
            fields: ["uid": uid]
        )
    }

    func syncLocalProfileToCloud(uid: String) async throws {
        ProfileBootstrapDebugLogger.event(
            "onboarding_cloud_sync_started",
            fields: ["uid": uid, "context": "reconcile"]
        )

        try await profileBootstrapService.syncOnboardingProfileToCloud(uid: uid)

        if let profile = try profileBootstrapService.currentProfile() {
            cloudSyncStore.markSynced(uid: uid, updatedAt: profile.updatedAt)
        }

        ProfileBootstrapDebugLogger.event(
            "onboarding_cloud_sync_completed",
            fields: ["uid": uid, "context": "reconcile"]
        )
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

        do {
            let presence = try await profileBootstrapService.fetchCloudProfilePresence(uid: uid)
            switch presence {
            case .absent:
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
            case .present(let document):
                ProfileBootstrapDebugLogger.event(
                    "cloud_profile_found",
                    fields: ["uid": uid, "context": "onboardingCompletion"]
                )
                return .cloudProfileConflict(document)
            }
        } catch {
            ProfileBootstrapDebugLogger.error(
                "cloud_profile_lookup_started",
                fields: ["uid": uid, "result": "failed"],
                underlying: error
            )
            return .cloudCheckFailed
        }
    }
}
