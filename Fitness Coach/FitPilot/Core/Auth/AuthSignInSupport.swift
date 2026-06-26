//
//  AuthSignInSupport.swift
//  Fitness Coach
//
//  FitPilot — Pure sign-in policy, copy, and error classification (no Firebase).
//

import Foundation

enum LaunchAuthPolicy {
    enum LaunchAction: Equatable {
        case startListeningOnly
    }

    static let launchAction: LaunchAction = .startListeningOnly
}

enum AuthCapabilities {
    static let supportsAnonymousSignIn = false
}

enum AuthSignInUserMessage {
    static let signInFailureTitle = "Sign-in failed"
    static let signInFailureMessage = "We couldn't sign you in. Please check your connection and try again."
    /// Canonical failure token stored in `AuthState.failed` and shown to users.
    static let signInFailure = signInFailureMessage
}

enum AuthSignInErrorClassifier {

    static let googleSignInErrorDomain = "com.google.GIDSignIn"
    static let canceledErrorCode = -5

    static func isCancellation(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == googleSignInErrorDomain
            && nsError.code == canceledErrorCode
    }

    static func userFacingSignInFailureMessage(for error: Error) -> String {
        if isCancellation(error) {
            return ""
        }
        return AuthSignInUserMessage.signInFailure
    }

    static func shouldSurfaceSignInFailure(for error: Error) -> Bool {
        !isCancellation(error)
    }
}

enum AuthInstallPolicy {

    static let installMarkerKey = "FitPilot.auth.installRegistered"

    static func isFreshInstall(hasInstallMarker: Bool) -> Bool {
        !hasInstallMarker
    }

    /// Keychain-backed auth can survive app deletion; always clear on first launch after install.
    static func shouldClearPersistedSessionOnLaunch(isFreshInstall: Bool) -> Bool {
        isFreshInstall
    }
}

enum AuthSessionPolicy {

    enum Resolution: Equatable {
        case acceptSignedIn
        case rejectNonGoogleSession
        case signedOut
        case preserveSigningIn
        case preserveFailed
    }

    static func resolve(
        hasUser: Bool,
        isGoogleUser: Bool,
        currentAuthState: AuthState
    ) -> Resolution {
        if hasUser {
            return isGoogleUser ? .acceptSignedIn : .rejectNonGoogleSession
        }

        if case .signingIn = currentAuthState {
            return .preserveSigningIn
        }

        if case .failed = currentAuthState {
            return .preserveFailed
        }

        return .signedOut
    }
}

enum AuthTokenPolicy {

    enum Eligibility: Equatable {
        case eligible
        case notSignedIn
    }

    static func eligibility(hasUser: Bool, isGoogleUser: Bool) -> Eligibility {
        guard hasUser, isGoogleUser else {
            return .notSignedIn
        }
        return .eligible
    }

    static func eligibilityToError(_ eligibility: Eligibility) -> AuthManagerError? {
        switch eligibility {
        case .eligible:
            return nil
        case .notSignedIn:
            return .notSignedIn
        }
    }
}

enum AuthSignInPresentationPolicy {

    struct FailurePresentation: Equatable {
        let title: String
        let message: String
    }

    static func shouldShowFailureBanner(authState: AuthState) -> Bool {
        if case .failed = authState {
            return true
        }
        return false
    }

    static func failurePresentation(authState: AuthState) -> FailurePresentation? {
        guard shouldShowFailureBanner(authState: authState) else {
            return nil
        }
        return FailurePresentation(
            title: AuthSignInUserMessage.signInFailureTitle,
            message: AuthSignInUserMessage.signInFailureMessage
        )
    }
}
