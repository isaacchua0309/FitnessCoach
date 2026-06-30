//
//  RootModel.swift
//  Fitness Coach
//
//  FitPilot AI — App root state for onboarding vs main tabs.
//

import Combine
import Foundation

enum RootViewState: Equatable {
    case loading
    /// Signed-in user acknowledged no cloud profile; awaiting setup onboarding.
    case missingCloudProfile
    /// Onboarding-completion sign-in found an existing cloud profile; user must choose.
    case onboardingCloudProfileConflict
    /// Cloud presence check failed during onboarding-completion sign-in.
    case onboardingCloudCheckFailed
    /// Cloud profile lookup failed during returning-member sign-in.
    case existingUserProfileLookupFailed
    /// Local profile saved but cloud backup failed.
    case cloudProfileUploadFailed
    /// Local profile belongs to a different Google account than the signed-in session.
    case accountProfileMismatch
    case onboarding
    case main
    case error(String)
}

@MainActor
final class RootModel: ObservableObject {

    @Published private(set) var state: RootViewState = .loading
    @Published private(set) var bootstrapPhase: ProfileBootstrapPhase = .idle

    private let profileBootstrapService: ProfileBootstrapService
    private var loadTask: Task<Void, Never>?
    private var currentUID: String?

    init(profileBootstrapService: ProfileBootstrapService) {
        self.profileBootstrapService = profileBootstrapService
    }

    private func applyState(_ newState: RootViewState, uid: String? = nil) {
        if let uid {
            currentUID = uid
        }
        state = newState
        bootstrapPhase = ProfileBootstrapCoordinator.bootstrapPhase(
            for: newState,
            uid: uid ?? currentUID
        )
    }

    func load(uid: String) {
        loadTask?.cancel()
        applyState(.loading, uid: uid)
        loadTask = Task {
            do {
                let result = try await profileBootstrapService.resolve(uid: uid)
                guard !Task.isCancelled else { return }
                applyState(RootProfileRouteResolver.resolve(bootstrapResult: result), uid: uid)
            } catch {
                guard !Task.isCancelled else { return }
                ProfileBootstrapDebugLogger.error(
                    "Profile bootstrap failed",
                    fields: ["uid": uid],
                    underlying: error
                )
                applyState(.error(FormaProductCopy.Onboarding.V2.BootstrapError.body), uid: uid)
            }
        }
    }

    /// Resolves root state from the on-device profile without cloud auth (pre-auth v2).
    /// Must only run while signed out; signed-in routing uses `load(uid:)`.
    func resolveLocalProfile() {
        loadTask?.cancel()
        let resolved = RootProfileRouteResolver.resolve(
            hasProfile: profileBootstrapService.hasLocalProfile()
        )
        applyState(resolved)
        bootstrapPhase = profileBootstrapService.hasLocalProfile() ? .localProfileReady : .needsOnboardingAfterCloudMiss
    }

    /// Neutral shell state after sign-out. Avoids treating signed-out users as signed-in onboarding.
    func resetForSignedOutSession() {
        loadTask?.cancel()
        applyState(.loading)
        bootstrapPhase = .idle
    }

    func didCompleteOnboarding() {
        loadTask?.cancel()
        applyState(.main)
        bootstrapPhase = .cloudProfileReady
    }

    func presentOnboardingCloudProfileConflict() {
        presentProfilePlanConflict()
    }

    func presentProfilePlanConflict() {
        loadTask?.cancel()
        applyState(.onboardingCloudProfileConflict)
    }

    func presentOnboardingCloudCheckFailed() {
        loadTask?.cancel()
        applyState(.onboardingCloudCheckFailed)
    }

    func presentExistingUserProfileLookupFailed() {
        loadTask?.cancel()
        applyState(.existingUserProfileLookupFailed)
    }

    func presentCloudProfileUploadFailed() {
        loadTask?.cancel()
        applyState(.cloudProfileUploadFailed)
    }

    func continueDespiteCloudUploadFailure() {
        loadTask?.cancel()
        applyState(.main)
        bootstrapPhase = .localProfileReady
    }

    func beginOnboardingCompletionCloudCheck() {
        loadTask?.cancel()
        applyState(.loading)
        bootstrapPhase = .uploadingCloud(redactedUID: currentUID.map(ProfileBootstrapDebugLogger.redactedUID) ?? "none")
    }

    func beginCloudSync() {
        bootstrapPhase = .awaitingCloudSync
    }

    func endCloudSync() {
        bootstrapPhase = .cloudProfileReady
    }

    /// Transitions from the post-sign-in missing-cloud interstitial into setup onboarding.
    func continueFromMissingCloudProfile() {
        applyState(.onboarding)
        bootstrapPhase = .needsOnboardingAfterCloudMiss
    }

    func presentMissingCloudProfile() {
        loadTask?.cancel()
        applyState(.missingCloudProfile)
        bootstrapPhase = .needsOnboardingAfterCloudMiss
    }

    func presentAccountProfileMismatch() {
        loadTask?.cancel()
        applyState(.accountProfileMismatch)
        bootstrapPhase = .checkingCloud(redactedUID: currentUID.map(ProfileBootstrapDebugLogger.redactedUID) ?? "none")
    }

    func presentAccountMismatchCloudCheckFailed() {
        loadTask?.cancel()
        applyState(.onboardingCloudCheckFailed)
    }

    func retry(uid: String) {
        load(uid: uid)
    }
}
