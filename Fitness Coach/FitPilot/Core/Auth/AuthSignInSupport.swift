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
    static let signInFailure = "Couldn't sign in with Google. Please try again."
    static let configurationFailure = "Couldn't start Google Sign-In. Please try again."
    static let presenterFailure = "Couldn't open Google Sign-In. Please try again."
    static let credentialFailure = "Couldn't complete sign-in. Please try again."
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

    static func shouldShowFailureBanner(authState: AuthState) -> Bool {
        if case .failed = authState {
            return true
        }
        return false
    }

    static func failureBannerMessage(
        authState: AuthState,
        errorMessage: String?
    ) -> String? {
        guard shouldShowFailureBanner(authState: authState) else {
            return nil
        }
        if let errorMessage, !errorMessage.isEmpty {
            return errorMessage
        }
        return AuthSignInUserMessage.signInFailure
    }
}
