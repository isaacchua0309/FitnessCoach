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
    case welcome
    case existingUserSignIn
    case onboardingStart
    case onboardingStartInitializing
    case signedInProfileLoading
    case noExistingProfileFound
    case onboardingCloudProfileConflict
    case onboardingCloudCheckFailed
    case existingUserProfileLookupFailed
    case cloudProfileUploadFailed
    case accountProfileMismatch
    case onboarding
    case onboardingInitializing
    case main
    /// Signed-in user with a local profile that still needs cloud upload.
    case mainAwaitingCloudSync
    case profileError(String)
}

/// Policy when a signed-out user already has a local profile — always require sign-in.
enum SignedOutWithProfilePolicy: Equatable, Sendable {
    case requireSignIn
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
    var publicEntryDestination: PublicEntryRoute
    var hasPersistedOnboardingDraft: Bool
    var suppressAutomaticPublicEntryResume: Bool

    init(
        authState: AuthState,
        hasLocalProfile: Bool,
        rootState: RootViewState = .loading,
        isOnboardingModelReady: Bool = false,
        signedOutWithProfilePolicy: SignedOutWithProfilePolicy = .requireSignIn,
        awaitingCloudSync: Bool = false,
        localProfileAwaitingSignIn: Bool = false,
        pendingOnboardingCompletion: Bool = false,
        publicEntryDestination: PublicEntryRoute = .welcome,
        hasPersistedOnboardingDraft: Bool = false,
        suppressAutomaticPublicEntryResume: Bool = false
    ) {
        self.authState = authState
        self.hasLocalProfile = hasLocalProfile
        self.rootState = rootState
        self.isOnboardingModelReady = isOnboardingModelReady
        self.signedOutWithProfilePolicy = signedOutWithProfilePolicy
        self.awaitingCloudSync = awaitingCloudSync
        self.localProfileAwaitingSignIn = localProfileAwaitingSignIn
        self.pendingOnboardingCompletion = pendingOnboardingCompletion
        self.publicEntryDestination = publicEntryDestination
        self.hasPersistedOnboardingDraft = hasPersistedOnboardingDraft
        self.suppressAutomaticPublicEntryResume = suppressAutomaticPublicEntryResume
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
