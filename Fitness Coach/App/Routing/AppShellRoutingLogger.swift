//
//  AppShellRoutingLogger.swift
//  Fitness Coach
//
//  Structured logging for auth-gated shell routing decisions.
//

import Foundation
import OSLog

enum AppShellRoutingLogger {

    nonisolated private static let logger = Logger(subsystem: "FitPilot", category: "AppShellRouting")

    nonisolated static func logDecision(
        authState: AuthState,
        rootState: RootViewState,
        hasLocalProfile: Bool,
        localProfileAwaitingSignIn: Bool,
        hasPersistedOnboardingDraft: Bool,
        suppressAutomaticPublicEntryResume: Bool,
        publicEntryDestination: PublicEntryRoute,
        isOnboardingModelReady: Bool,
        baseRoute: AppShellRoute,
        selectedRoute: AppShellRoute,
        trigger: String
    ) {
        let authLabel = authStateLabel(authState)
        var fields: [String: String] = [
            "trigger": trigger,
            "authState": authLabel,
            "rootState": rootStateLabel(rootState),
            "hasLocalProfile": String(hasLocalProfile),
            "localProfileAwaitingSignIn": String(localProfileAwaitingSignIn),
            "hasPersistedOnboardingDraft": String(hasPersistedOnboardingDraft),
            "suppressAutomaticPublicEntryResume": String(suppressAutomaticPublicEntryResume),
            "publicEntryDestination": publicEntryDestinationLabel(publicEntryDestination),
            "isOnboardingModelReady": String(isOnboardingModelReady),
            "baseRoute": shellRouteLabel(baseRoute),
            "selectedRoute": shellRouteLabel(selectedRoute)
        ]
        if case .signedIn(let uid) = authState {
            fields["uid"] = ProfileBootstrapDebugLogger.redactedUID(uid)
        }
        emit(message: "app_shell_route_resolved", fields: fields)
    }

    nonisolated static func logLogoutEvent(
        source: String,
        wasSignedIn: Bool,
        hasLocalProfile: Bool,
        hasPersistedOnboardingDraft: Bool,
        publicEntryDestination: PublicEntryRoute
    ) {
        emit(
            message: "logout_session_reset",
            fields: [
                "source": source,
                "wasSignedIn": String(wasSignedIn),
                "hasLocalProfile": String(hasLocalProfile),
                "hasPersistedOnboardingDraft": String(hasPersistedOnboardingDraft),
                "publicEntryDestination": publicEntryDestinationLabel(publicEntryDestination)
            ]
        )
    }

    nonisolated private static func emit(message: String, fields: [String: String]) {
        let fieldLine = fields
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")
        let line = fieldLine.isEmpty
            ? "[AppShellRouting] \(message)"
            : "[AppShellRouting] \(message) \(fieldLine)"
        logger.log(level: .info, "\(line, privacy: .public)")
    }

    nonisolated private static func authStateLabel(_ state: AuthState) -> String {
        switch state {
        case .unknown:
            return "unknown"
        case .signedOut:
            return "signedOut"
        case .signingIn:
            return "signingIn"
        case .signedIn:
            return "signedIn"
        case .failed:
            return "failed"
        }
    }

    nonisolated private static func rootStateLabel(_ state: RootViewState) -> String {
        switch state {
        case .loading:
            return "loading"
        case .missingCloudProfile:
            return "missingCloudProfile"
        case .onboardingCloudProfileConflict:
            return "onboardingCloudProfileConflict"
        case .onboardingCloudCheckFailed:
            return "onboardingCloudCheckFailed"
        case .existingUserProfileLookupFailed:
            return "existingUserProfileLookupFailed"
        case .cloudProfileUploadFailed:
            return "cloudProfileUploadFailed"
        case .accountProfileMismatch:
            return "accountProfileMismatch"
        case .onboarding:
            return "onboarding"
        case .main:
            return "main"
        case .error:
            return "error"
        }
    }

    nonisolated private static func publicEntryDestinationLabel(_ destination: PublicEntryRoute) -> String {
        switch destination {
        case .welcome:
            return "welcome"
        case .existingUserSignIn:
            return "existingUserSignIn"
        case .onboardingStart:
            return "onboardingStart"
        }
    }

    nonisolated private static func shellRouteLabel(_ route: AppShellRoute) -> String {
        switch route {
        case .launchLoading:
            return "launchLoading"
        case .welcome:
            return "welcome"
        case .existingUserSignIn:
            return "existingUserSignIn"
        case .onboardingStart:
            return "onboardingStart"
        case .onboardingStartInitializing:
            return "onboardingStartInitializing"
        case .signedInProfileLoading:
            return "signedInProfileLoading"
        case .noExistingProfileFound:
            return "noExistingProfileFound"
        case .onboardingCloudProfileConflict:
            return "onboardingCloudProfileConflict"
        case .onboardingCloudCheckFailed:
            return "onboardingCloudCheckFailed"
        case .existingUserProfileLookupFailed:
            return "existingUserProfileLookupFailed"
        case .cloudProfileUploadFailed:
            return "cloudProfileUploadFailed"
        case .accountProfileMismatch:
            return "accountProfileMismatch"
        case .onboarding:
            return "onboarding"
        case .onboardingInitializing:
            return "onboardingInitializing"
        case .main:
            return "main"
        case .profileError:
            return "profileError"
        }
    }
}
