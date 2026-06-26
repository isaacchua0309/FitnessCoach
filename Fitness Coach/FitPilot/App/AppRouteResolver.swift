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
    case signedInProfileLoading
    case onboarding
    case onboardingInitializing
    case main
    case profileError(String)
}

enum AppRouteResolver {

    static func resolve(
        authState: AuthState,
        rootState: RootViewState = .loading,
        isOnboardingModelReady: Bool = false
    ) -> AppShellRoute {
        switch authState {
        case .unknown:
            return .launchLoading
        case .signedOut, .signingIn, .failed:
            return .signIn
        case .signedIn:
            switch rootState {
            case .loading:
                return .signedInProfileLoading
            case .onboarding:
                return isOnboardingModelReady ? .onboarding : .onboardingInitializing
            case .main:
                return .main
            case .error(let message):
                return .profileError(message)
            }
        }
    }

    static func isSignedIn(_ state: AuthState) -> Bool {
        if case .signedIn = state {
            return true
        }
        return false
    }

    static func shouldClearOnboardingModel(wasSignedIn: Bool, isSignedIn: Bool) -> Bool {
        wasSignedIn && !isSignedIn
    }

    static func shouldRotateSignedInSession(wasSignedIn: Bool, isSignedIn: Bool) -> Bool {
        isSignedIn && !wasSignedIn
    }
}

enum RootProfileRouteResolver {

    static func resolve(hasProfile: Bool) -> RootViewState {
        hasProfile ? .main : .onboarding
    }
}

enum AuthLogoutPolicy {
    static let deletesLocalProfileOnSignOut = false
}
