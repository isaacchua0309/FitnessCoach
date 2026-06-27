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
    case onboarding
    case main
    case error(String)
}

@MainActor
final class RootModel: ObservableObject {

    @Published private(set) var state: RootViewState = .loading

    private let profileBootstrapService: ProfileBootstrapService
    private var loadTask: Task<Void, Never>?

    init(profileBootstrapService: ProfileBootstrapService) {
        self.profileBootstrapService = profileBootstrapService
    }

    func load(uid: String) {
        loadTask?.cancel()
        state = .loading
        loadTask = Task {
            do {
                let result = try await profileBootstrapService.resolve(uid: uid)
                guard !Task.isCancelled else { return }
                state = RootProfileRouteResolver.resolve(bootstrapResult: result)
            } catch {
                guard !Task.isCancelled else { return }
                ProfileBootstrapDebugLogger.error(
                    "Profile bootstrap failed",
                    fields: ["uid": uid],
                    underlying: error
                )
                state = .error(FormaProductCopy.Onboarding.V2.BootstrapError.body)
            }
        }
    }

    /// Resolves root state from the on-device profile without cloud auth (pre-auth v2).
    /// Must only run while signed out; signed-in routing uses `load(uid:)`.
    func resolveLocalProfile() {
        loadTask?.cancel()
        state = RootProfileRouteResolver.resolve(
            hasProfile: profileBootstrapService.hasLocalProfile()
        )
    }

    func didCompleteOnboarding() {
        loadTask?.cancel()
        state = .main
    }

    /// Transitions from the post-sign-in missing-cloud interstitial into setup onboarding.
    func continueFromMissingCloudProfile() {
        state = .onboarding
    }

    func retry(uid: String) {
        load(uid: uid)
    }
}
