//
//  OnboardingShellRouteResolver.swift
//  Fitness Coach
//
//  Forma — Pure onboarding shell routing (testable without SwiftUI).
//

import Foundation

/// Shell destinations for onboarding routing.
enum OnboardingShellRoute: Equatable {
    case launchLoading
    /// Signed-out user with no local profile — onboarding before auth.
    case preAuthOnboarding
    case preAuthOnboardingInitializing
    /// Returning user with a local profile who chose sign-in from the pre-auth landing.
    case signIn
    /// Signed-out user with a local profile allowed to use the app locally.
    case localMain
    case signedInProfileLoading
    case missingCloudProfile
    case onboardingCloudProfileConflict
    case onboardingCloudCheckFailed
    case cloudProfileUploadFailed
    case accountProfileMismatch
    case onboarding
    case onboardingInitializing
    case main
    /// Signed-in user with a local profile that still needs cloud upload.
    case mainAwaitingCloudSync
    case profileError(String)
}

/// Policy when a signed-out user already has a local profile.
enum SignedOutWithProfilePolicy: Equatable, Sendable {
    /// Current production behavior — require Google sign-in.
    case requireSignIn
    /// Optional future path — enter main tabs locally without auth.
    case allowLocalMain
}

struct OnboardingShellRouteInput: Equatable, Sendable {
    var authState: AuthState
    var hasLocalProfile: Bool
    var rootState: RootViewState
    var isOnboardingModelReady: Bool
    var signedOutWithProfilePolicy: SignedOutWithProfilePolicy
    var awaitingCloudSync: Bool
    var localProfileAwaitingSignIn: Bool
    var pendingOnboardingCompletion: Bool

    init(
        authState: AuthState,
        hasLocalProfile: Bool,
        rootState: RootViewState = .loading,
        isOnboardingModelReady: Bool = false,
        signedOutWithProfilePolicy: SignedOutWithProfilePolicy = .requireSignIn,
        awaitingCloudSync: Bool = false,
        localProfileAwaitingSignIn: Bool = false,
        pendingOnboardingCompletion: Bool = false
    ) {
        self.authState = authState
        self.hasLocalProfile = hasLocalProfile
        self.rootState = rootState
        self.isOnboardingModelReady = isOnboardingModelReady
        self.signedOutWithProfilePolicy = signedOutWithProfilePolicy
        self.awaitingCloudSync = awaitingCloudSync
        self.localProfileAwaitingSignIn = localProfileAwaitingSignIn
        self.pendingOnboardingCompletion = pendingOnboardingCompletion
    }
}

enum OnboardingShellRouteResolver {

    static func resolve(_ input: OnboardingShellRouteInput) -> OnboardingShellRoute {
        let appRoute = AppRouteResolver.resolve(AppRouteInput(input))
        return OnboardingShellRoute(appShellRoute: appRoute, awaitingCloudSync: input.awaitingCloudSync)
    }

    static func resolve(
        authState: AuthState,
        hasLocalProfile: Bool,
        rootState: RootViewState = .loading,
        isOnboardingModelReady: Bool = false,
        signedOutWithProfilePolicy: SignedOutWithProfilePolicy = .requireSignIn,
        awaitingCloudSync: Bool = false
    ) -> OnboardingShellRoute {
        resolve(
            OnboardingShellRouteInput(
                authState: authState,
                hasLocalProfile: hasLocalProfile,
                rootState: rootState,
                isOnboardingModelReady: isOnboardingModelReady,
                signedOutWithProfilePolicy: signedOutWithProfilePolicy,
                awaitingCloudSync: awaitingCloudSync
            )
        )
    }
}

extension OnboardingShellRouteResolver {

    static func legacyEquivalent(for route: OnboardingShellRoute) -> AppShellRoute? {
        AppShellRoute(onboardingShellRoute: route)
    }
}
