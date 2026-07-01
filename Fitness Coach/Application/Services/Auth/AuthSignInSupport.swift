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
    static let signInFailureTitle = FormaProductCopy.Error.signInTitle
    static let signInFailureMessage = FormaProductCopy.Error.signInMessage
    /// Canonical failure token stored in `AuthState.failed` and shown to users.
    static let signInFailure = signInFailureMessage
}

// MARK: - Google sign-in attempt state machine

/// Terminal and in-flight outcomes returned by `AuthManager.signInWithGoogle()`.
enum GoogleSignInAttemptOutcome: Equatable, Sendable {
    case success(uid: String)
    case cancelled
    case failed(message: String)
}

/// UI-facing Google sign-in phases composed from auth session + in-flight flag.
enum GoogleSignInAttemptState: Equatable, Sendable {
    case idle
    case signingIn
    case authenticated(uid: String)
    case cancelled
    case failed(message: String)

    static func resolve(
        authState: AuthState,
        isPerformingGoogleSignIn: Bool
    ) -> GoogleSignInAttemptState {
        if isPerformingGoogleSignIn {
            return .signingIn
        }

        switch authState {
        case .signedIn(let uid):
            return .authenticated(uid: uid)
        case .failed(let message):
            return .failed(message: message)
        case .signedOut, .unknown:
            return .idle
        case .signingIn:
            // Stale shell state — treat as idle so buttons are never permanently disabled.
            return .idle
        }
    }

    var isButtonLoading: Bool {
        self == .signingIn
    }

    var isButtonDisabled: Bool {
        switch self {
        case .signingIn, .authenticated:
            return true
        case .idle, .cancelled, .failed:
            return false
        }
    }
}

enum AuthSignInErrorClassifier {

    static let googleSignInErrorDomain = "com.google.GIDSignIn"
    static let canceledErrorCode = -5
    static let webAuthenticationSessionDomain =
        "com.apple.AuthenticationServices.WebAuthenticationSession"
    static let webAuthenticationSessionCanceledCode = 1

    static func isCancellation(_ error: Error) -> Bool {
        let nsError = error as NSError

        if nsError.domain == googleSignInErrorDomain,
           nsError.code == canceledErrorCode {
            return true
        }

        if nsError.domain == webAuthenticationSessionDomain,
           nsError.code == webAuthenticationSessionCanceledCode {
            return true
        }

        if nsError.domain == NSURLErrorDomain,
           nsError.code == URLError.Code.cancelled.rawValue {
            return true
        }

        return false
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
