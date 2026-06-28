//
//  ExistingUserSignInPolicy.swift
//  Fitness Coach
//
//  Forma — Pure policy for returning-member sign-in failures and copy.
//

import Foundation

enum ExistingUserSignInFailureKind: String, Equatable, Sendable {
    case authCancelled
    case authFailed
    case networkFailed
    case profileLookupFailed

    var analyticsReason: String { rawValue }
}

enum ExistingUserSignInPolicy {

    struct FailurePresentation: Equatable, Sendable {
        let kind: ExistingUserSignInFailureKind
        let title: String
        let message: String
    }

    static func didSignInAttemptFail(from previous: AuthState, to state: AuthState) -> Bool {
        switch (previous, state) {
        case (.signingIn, .signedOut), (.signingIn, .failed):
            return true
        default:
            return false
        }
    }

    static func failureKind(from previous: AuthState, to state: AuthState) -> ExistingUserSignInFailureKind? {
        guard didSignInAttemptFail(from: previous, to: state) else {
            return nil
        }
        if case .signedOut = state {
            return .authCancelled
        }
        if case .failed(let message) = state {
            if message == AuthSignInUserMessage.signInFailureMessage {
                return .networkFailed
            }
            return .authFailed
        }
        return .authFailed
    }

    static func presentation(for kind: ExistingUserSignInFailureKind) -> FailurePresentation {
        let copy = FormaProductCopy.PublicEntry.ExistingUserSignIn.Error.self
        switch kind {
        case .authCancelled:
            return FailurePresentation(
                kind: kind,
                title: copy.cancelledTitle,
                message: copy.cancelledMessage
            )
        case .authFailed:
            return FailurePresentation(
                kind: kind,
                title: copy.authFailedTitle,
                message: copy.authFailedMessage
            )
        case .networkFailed:
            return FailurePresentation(
                kind: kind,
                title: copy.networkFailedTitle,
                message: copy.networkFailedMessage
            )
        case .profileLookupFailed:
            return FailurePresentation(
                kind: kind,
                title: copy.profileLookupFailedTitle,
                message: copy.profileLookupFailedMessage
            )
        }
    }
}
