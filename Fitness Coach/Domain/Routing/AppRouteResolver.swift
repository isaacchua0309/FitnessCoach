//
//  AppRouteResolver.swift
//  Fitness Coach
//
//  FitPilot — Pure auth-gated shell routing (testable without SwiftUI).
//

import Foundation

enum AppShellRoute: Equatable {
    case launchLoading
    case signIn
    /// Signed-out pre-auth onboarding (v2).
    case localOnboarding
    case localOnboardingInitializing
    /// Signed-out user with a local profile allowed to enter main without auth (v2 policy).
    case localMain
    case signedInProfileLoading
    /// Signed-in user with no local/cloud profile before setup onboarding.
    case missingCloudProfile
    case onboardingCloudProfileConflict
    case onboardingCloudCheckFailed
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
    var isOnboardingV2Enabled: Bool
    var signedOutWithProfilePolicy: SignedOutWithProfilePolicy

    init(
        authState: AuthState,
        hasLocalProfile: Bool = false,
        rootState: RootViewState = .loading,
        isOnboardingModelReady: Bool = false,
        isOnboardingV2Enabled: Bool = false,
        signedOutWithProfilePolicy: SignedOutWithProfilePolicy = .requireSignIn
    ) {
        self.authState = authState
        self.hasLocalProfile = hasLocalProfile
        self.rootState = rootState
        self.isOnboardingModelReady = isOnboardingModelReady
        self.isOnboardingV2Enabled = isOnboardingV2Enabled
        self.signedOutWithProfilePolicy = signedOutWithProfilePolicy
    }
}

enum AppRouteResolver {

    static func resolve(
        authState: AuthState,
        rootState: RootViewState = .loading,
        isOnboardingModelReady: Bool = false,
        hasLocalProfile: Bool = false,
        isOnboardingV2Enabled: Bool = false,
        signedOutWithProfilePolicy: SignedOutWithProfilePolicy = .requireSignIn
    ) -> AppShellRoute {
        resolve(
            AppRouteInput(
                authState: authState,
                hasLocalProfile: hasLocalProfile,
                rootState: rootState,
                isOnboardingModelReady: isOnboardingModelReady,
                isOnboardingV2Enabled: isOnboardingV2Enabled,
                signedOutWithProfilePolicy: signedOutWithProfilePolicy
            )
        )
    }

    static func resolve(_ input: AppRouteInput) -> AppShellRoute {
        if input.isOnboardingV2Enabled {
            return resolveV2(input)
        }
        return resolveLegacy(input)
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

    // MARK: - V2

    private static func resolveV2(_ input: AppRouteInput) -> AppShellRoute {
        switch input.authState {
        case .unknown:
            return .launchLoading
        case .signedOut, .signingIn, .failed:
            return resolveSignedOutV2(input)
        case .signedIn:
            return resolveSignedIn(input)
        }
    }

    private static func resolveSignedOutV2(_ input: AppRouteInput) -> AppShellRoute {
        if input.hasLocalProfile, input.signedOutWithProfilePolicy == .allowLocalMain {
            return .localMain
        }

        return input.isOnboardingModelReady
            ? .localOnboarding
            : .localOnboardingInitializing
    }

    // MARK: - Legacy / shared signed-in

    private static func resolveLegacy(_ input: AppRouteInput) -> AppShellRoute {
        switch input.authState {
        case .unknown:
            return .launchLoading
        case .signedOut, .signingIn, .failed:
            return .signIn
        case .signedIn:
            return resolveSignedIn(input)
        }
    }

    private static func resolveSignedIn(_ input: AppRouteInput) -> AppShellRoute {
        switch input.rootState {
        case .loading:
            return .signedInProfileLoading
        case .missingCloudProfile:
            return .missingCloudProfile
        case .onboardingCloudProfileConflict:
            return .onboardingCloudProfileConflict
        case .onboardingCloudCheckFailed:
            return .onboardingCloudCheckFailed
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
}

extension AppRouteInput {

    init(_ shellInput: OnboardingShellRouteInput) {
        self.init(
            authState: shellInput.authState,
            hasLocalProfile: shellInput.hasLocalProfile,
            rootState: shellInput.rootState,
            isOnboardingModelReady: shellInput.isOnboardingModelReady,
            isOnboardingV2Enabled: shellInput.isOnboardingV2Enabled,
            signedOutWithProfilePolicy: shellInput.signedOutWithProfilePolicy
        )
    }
}

extension OnboardingShellRoute {

    init(appShellRoute: AppShellRoute, awaitingCloudSync: Bool = false) {
        switch appShellRoute {
        case .launchLoading:
            self = .launchLoading
        case .signIn:
            self = .signIn
        case .localOnboarding:
            self = .preAuthOnboarding
        case .localOnboardingInitializing:
            self = .preAuthOnboardingInitializing
        case .localMain:
            self = .localMain
        case .signedInProfileLoading:
            self = .signedInProfileLoading
        case .missingCloudProfile:
            self = .missingCloudProfile
        case .onboardingCloudProfileConflict:
            self = .onboardingCloudProfileConflict
        case .onboardingCloudCheckFailed:
            self = .onboardingCloudCheckFailed
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
        case .signIn:
            self = .signIn
        case .preAuthOnboarding:
            self = .localOnboarding
        case .preAuthOnboardingInitializing:
            self = .localOnboardingInitializing
        case .localMain:
            self = .localMain
        case .signedInProfileLoading:
            self = .signedInProfileLoading
        case .missingCloudProfile:
            self = .missingCloudProfile
        case .onboardingCloudProfileConflict:
            self = .onboardingCloudProfileConflict
        case .onboardingCloudCheckFailed:
            self = .onboardingCloudCheckFailed
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
