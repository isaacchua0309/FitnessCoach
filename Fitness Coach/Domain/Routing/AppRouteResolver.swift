//
//  AppRouteResolver.swift
//  Fitness Coach
//
//  FitPilot — Pure auth-gated shell routing (testable without SwiftUI).
//

import Foundation

enum AppShellRoute: Equatable {
    case launchLoading
    /// Logged-out public entry landing.
    case welcome
    /// Dedicated returning-user sign-in (not onboarding save-plan sign-in).
    case existingUserSignIn
    /// Signed-out onboarding funnel entry.
    case onboardingStart
    case onboardingStartInitializing
    /// Signed-out user with a local profile allowed to enter main without auth.
    case localMain
    case signedInProfileLoading
    /// Signed-in user with no local/cloud profile — invite into onboarding.
    case noExistingProfileFound
    case onboardingCloudProfileConflict
    case onboardingCloudCheckFailed
    case existingUserProfileLookupFailed
    case cloudProfileUploadFailed
    case accountProfileMismatch
    case onboarding
    case onboardingInitializing
    case main
    case profileError(String)
}

struct AppRouteInput: Equatable, Sendable {
    var authState: AuthState
    var hasLocalProfile: Bool
    var rootState: RootViewState
    var isOnboardingModelReady: Bool
    var signedOutWithProfilePolicy: SignedOutWithProfilePolicy
    var localProfileAwaitingSignIn: Bool
    var pendingOnboardingCompletion: Bool
    var publicEntryDestination: PublicEntryRoute
    var hasPersistedOnboardingDraft: Bool

    init(
        authState: AuthState,
        hasLocalProfile: Bool = false,
        rootState: RootViewState = .loading,
        isOnboardingModelReady: Bool = false,
        signedOutWithProfilePolicy: SignedOutWithProfilePolicy = .requireSignIn,
        localProfileAwaitingSignIn: Bool = false,
        pendingOnboardingCompletion: Bool = false,
        publicEntryDestination: PublicEntryRoute = .welcome,
        hasPersistedOnboardingDraft: Bool = false
    ) {
        self.authState = authState
        self.hasLocalProfile = hasLocalProfile
        self.rootState = rootState
        self.isOnboardingModelReady = isOnboardingModelReady
        self.signedOutWithProfilePolicy = signedOutWithProfilePolicy
        self.localProfileAwaitingSignIn = localProfileAwaitingSignIn
        self.pendingOnboardingCompletion = pendingOnboardingCompletion
        self.publicEntryDestination = publicEntryDestination
        self.hasPersistedOnboardingDraft = hasPersistedOnboardingDraft
    }
}

enum AppRouteResolver {

    static func resolve(
        authState: AuthState,
        rootState: RootViewState = .loading,
        isOnboardingModelReady: Bool = false,
        hasLocalProfile: Bool = false,
        signedOutWithProfilePolicy: SignedOutWithProfilePolicy = .requireSignIn,
        localProfileAwaitingSignIn: Bool = false,
        pendingOnboardingCompletion: Bool = false,
        publicEntryDestination: PublicEntryRoute = .welcome,
        hasPersistedOnboardingDraft: Bool = false
    ) -> AppShellRoute {
        resolve(
            AppRouteInput(
                authState: authState,
                hasLocalProfile: hasLocalProfile,
                rootState: rootState,
                isOnboardingModelReady: isOnboardingModelReady,
                signedOutWithProfilePolicy: signedOutWithProfilePolicy,
                localProfileAwaitingSignIn: localProfileAwaitingSignIn,
                pendingOnboardingCompletion: pendingOnboardingCompletion,
                publicEntryDestination: publicEntryDestination,
                hasPersistedOnboardingDraft: hasPersistedOnboardingDraft
            )
        )
    }

    static func resolve(_ input: AppRouteInput) -> AppShellRoute {
        switch input.authState {
        case .unknown:
            return .launchLoading
        case .signedOut, .signingIn, .failed:
            return resolveSignedOutPreAuth(input)
        case .signedIn:
            return resolveSignedIn(input)
        }
    }

    static func isSignedIn(_ state: AuthState) -> Bool {
        if case .signedIn = state {
            return true
        }
        return false
    }

    static func shouldClearOnboardingModel(
        wasSignedIn: Bool,
        isSignedIn: Bool,
        hasLocalProfile: Bool = false,
        hasPersistedOnboardingDraft: Bool = false
    ) -> Bool {
        AuthGateRoutingPolicy.shouldClearOnboardingModelOnSignOut(
            wasSignedIn: wasSignedIn,
            isSignedIn: isSignedIn,
            hasLocalProfile: hasLocalProfile,
            hasPersistedOnboardingDraft: hasPersistedOnboardingDraft
        )
    }

    static func shouldRotateSignedInSession(wasSignedIn: Bool, isSignedIn: Bool) -> Bool {
        isSignedIn && !wasSignedIn
    }

    private static func resolveSignedOutPreAuth(_ input: AppRouteInput) -> AppShellRoute {
        PublicEntryRouteResolver.resolveSignedOutShell(
            PublicEntryRouteResolver.Input(
                destination: input.publicEntryDestination,
                isOnboardingModelReady: input.isOnboardingModelReady,
                localProfileAwaitingSignIn: input.localProfileAwaitingSignIn,
                hasPersistedOnboardingDraft: input.hasPersistedOnboardingDraft,
                hasLocalProfile: input.hasLocalProfile,
                pendingOnboardingCompletion: input.pendingOnboardingCompletion,
                signedOutWithProfilePolicy: input.signedOutWithProfilePolicy
            )
        )
    }

    // MARK: - Signed-in

    private static func resolveSignedIn(_ input: AppRouteInput) -> AppShellRoute {
        switch input.rootState {
        case .loading:
            return .signedInProfileLoading
        case .missingCloudProfile:
            return .noExistingProfileFound
        case .onboardingCloudProfileConflict:
            return .onboardingCloudProfileConflict
        case .onboardingCloudCheckFailed:
            return .onboardingCloudCheckFailed
        case .existingUserProfileLookupFailed:
            return .existingUserProfileLookupFailed
        case .cloudProfileUploadFailed:
            return .cloudProfileUploadFailed
        case .accountProfileMismatch:
            return .accountProfileMismatch
        case .onboarding:
            return input.isOnboardingModelReady ? .onboarding : .onboardingInitializing
        case .main:
            return .main
        case .error(let message):
            return .profileError(message)
        }
    }
}

enum RootProfileRouteResolver {

    static func resolve(hasProfile: Bool) -> RootViewState {
        hasProfile ? .main : .onboarding
    }

    static func resolve(bootstrapResult: ProfileBootstrapResult) -> RootViewState {
        switch bootstrapResult {
        case .main:
            return .main
        case .missingCloudProfile:
            return .missingCloudProfile
        }
    }
}

enum AuthLogoutPolicy {
    static let deletesLocalProfileOnSignOut = false
    /// Session-scoped cloud sync hints must not survive sign-out; `ownerUID` remains authoritative.
    static let clearsCloudSyncMetadataOnSignOut = true

    static func clearTransientSessionMetadata(cloudSyncStore: ProfileCloudSyncStore) {
        guard clearsCloudSyncMetadataOnSignOut else { return }
        cloudSyncStore.clear()
    }
}

extension AppRouteInput {

    init(_ shellInput: OnboardingShellRouteInput) {
        self.init(
            authState: shellInput.authState,
            hasLocalProfile: shellInput.hasLocalProfile,
            rootState: shellInput.rootState,
            isOnboardingModelReady: shellInput.isOnboardingModelReady,
            signedOutWithProfilePolicy: shellInput.signedOutWithProfilePolicy,
            localProfileAwaitingSignIn: shellInput.localProfileAwaitingSignIn,
            pendingOnboardingCompletion: shellInput.pendingOnboardingCompletion,
            publicEntryDestination: shellInput.publicEntryDestination,
            hasPersistedOnboardingDraft: shellInput.hasPersistedOnboardingDraft
        )
    }
}

extension OnboardingShellRoute {

    init(appShellRoute: AppShellRoute, awaitingCloudSync: Bool = false) {
        switch appShellRoute {
        case .launchLoading:
            self = .launchLoading
        case .welcome:
            self = .welcome
        case .existingUserSignIn:
            self = .existingUserSignIn
        case .onboardingStart:
            self = .onboardingStart
        case .onboardingStartInitializing:
            self = .onboardingStartInitializing
        case .localMain:
            self = .localMain
        case .signedInProfileLoading:
            self = .signedInProfileLoading
        case .noExistingProfileFound:
            self = .noExistingProfileFound
        case .onboardingCloudProfileConflict:
            self = .onboardingCloudProfileConflict
        case .onboardingCloudCheckFailed:
            self = .onboardingCloudCheckFailed
        case .existingUserProfileLookupFailed:
            self = .existingUserProfileLookupFailed
        case .cloudProfileUploadFailed:
            self = .cloudProfileUploadFailed
        case .accountProfileMismatch:
            self = .accountProfileMismatch
        case .onboarding:
            self = .onboarding
        case .onboardingInitializing:
            self = .onboardingInitializing
        case .main:
            self = awaitingCloudSync ? .mainAwaitingCloudSync : .main
        case .profileError(let message):
            self = .profileError(message)
        }
    }
}

extension AppShellRoute {

    init(onboardingShellRoute: OnboardingShellRoute) {
        switch onboardingShellRoute {
        case .launchLoading:
            self = .launchLoading
        case .welcome:
            self = .welcome
        case .existingUserSignIn:
            self = .existingUserSignIn
        case .onboardingStart:
            self = .onboardingStart
        case .onboardingStartInitializing:
            self = .onboardingStartInitializing
        case .localMain:
            self = .localMain
        case .signedInProfileLoading:
            self = .signedInProfileLoading
        case .noExistingProfileFound:
            self = .noExistingProfileFound
        case .onboardingCloudProfileConflict:
            self = .onboardingCloudProfileConflict
        case .onboardingCloudCheckFailed:
            self = .onboardingCloudCheckFailed
        case .existingUserProfileLookupFailed:
            self = .existingUserProfileLookupFailed
        case .cloudProfileUploadFailed:
            self = .cloudProfileUploadFailed
        case .accountProfileMismatch:
            self = .accountProfileMismatch
        case .onboarding:
            self = .onboarding
        case .onboardingInitializing:
            self = .onboardingInitializing
        case .main, .mainAwaitingCloudSync:
            self = .main
        case .profileError(let message):
            self = .profileError(message)
        }
    }
}
